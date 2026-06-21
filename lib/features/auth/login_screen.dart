import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_config.dart';
import '../../l10n/app_localizations.dart';
import '../onboarding/connection_editor.dart';
import 'auth_providers.dart';

/// Login + Registrierung (E-Mail/Passwort) in einem Screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = ref.read(authRepositoryProvider);
    try {
      if (_isSignUp) {
        final res = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        );
        // Wenn E-Mail-Bestätigung aktiv ist, gibt es noch keine Session.
        if (res.session == null && mounted) {
          setState(() => _isSignUp = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context).almostDone),
          ));
        }
      } else {
        await auth.signIn(email: _email.text.trim(), password: _password.text);
      }
      // Die Umleitung übernimmt der Router automatisch über den Auth-Zustand.
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Unerwarteter Fehler: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _forgotPassword() async {
    final l = AppLocalizations.of(context);
    final emailCtrl = TextEditingController(text: _email.text.trim());
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.resetPasswordTitle),
        content: TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l.email,
            prefixIcon: const Icon(Icons.email_outlined),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(l.cancel)),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, emailCtrl.text.trim()),
              child: Text(l.sendLink)),
        ],
      ),
    );
    if (email == null || !email.contains('@')) return;
    try {
      await ref.read(authRepositoryProvider).resetPassword(email);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.resetSent)));
      }
    } catch (e) {
      _showError('Fehler: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 56,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Money Manager',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 32),
                  if (_isSignUp) ...[
                    TextFormField(
                      controller: _name,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: l.displayNameOptional,
                        prefixIcon: const Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: l.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                    validator: (v) =>
                        (v == null || !v.contains('@')) ? l.invalidEmail : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l.password,
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                    validator: (v) =>
                        (v == null || v.length < 6) ? l.passwordMin : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isSignUp ? l.register : l.signIn),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() => _isSignUp = !_isSignUp),
                    child: Text(_isSignUp ? l.haveAccount : l.newHere),
                  ),
                  if (!_isSignUp)
                    TextButton(
                      onPressed: _loading ? null : _forgotPassword,
                      child: Text(l.forgotPassword),
                    ),
                  // Verbindungs-Knopf nur zeigen, wenn er gebraucht wird:
                  // wenn ein eigener Override aktiv ist (z. B. falsche URL zum
                  // Zuruecksetzen) oder gar keine feste Verbindung eingebaut ist
                  // (Fork). Fuer normale Besucher der Standard-Instanz bleibt er
                  // verborgen.
                  Builder(builder: (context) {
                    final config = ref.watch(appConfigProvider);
                    if (config.hasBakedDefault && !config.isUsingOverride) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () => showConnectionEditor(context, ref),
                        icon: const Icon(Icons.dns_outlined, size: 18),
                        label: Text(l.changeDbConnection),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
