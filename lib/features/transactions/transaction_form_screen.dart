import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../data/models/account.dart';
import '../../data/models/app_transaction.dart';
import '../../data/models/audit_entry.dart';
import '../../data/models/category.dart';
import '../../data/models/transaction_template.dart';
import '../../l10n/app_localizations.dart';
import '../profile/profile_providers.dart';
import '../../shared/calculator_sheet.dart';
import '../../shared/category_icons.dart';
import '../../shared/image_compress.dart';
import 'comments_section.dart';
import 'ocr/receipt_ocr.dart';
import '../../shared/money.dart';
import '../../shared/tag_editor.dart';
import '../accounts/account_providers.dart';
import '../categories/category_providers.dart';
import 'transaction_providers.dart';

/// Buchung erfassen ODER bearbeiten. Das Konto wird hier gewählt; kommt man von
/// einem Konto, ist es vorausgewählt.
class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    super.key,
    this.accountId,
    this.transactionId,
  });

  /// Vorausgewähltes Quellkonto (z. B. aus der Konto-Detailansicht).
  final String? accountId;

  /// Wenn gesetzt: Bearbeitungsmodus.
  final String? transactionId;

  bool get isEditing => transactionId != null;

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _titleInitial = '';
  TextEditingController? _titleCtrl;
  String? _accountId;
  TransactionType _type = TransactionType.expense;
  DateTime _date = DateTime.now();
  String? _categoryId;
  String? _transferTargetId;
  bool _saving = false;
  bool _prefilled = false;
  String? _receiptPath;
  bool _receiptBusy = false;
  Future<String>? _receiptUrlFuture;
  List<String> _tags = [];
  bool _splitMode = false;
  final List<_SplitRow> _splitRows = [];
  bool _splitsPrefilled = false;

  @override
  void initState() {
    super.initState();
    _accountId = widget.accountId;
    _splitsPrefilled = widget.transactionId == null; // nur beim Bearbeiten laden
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    for (final r in _splitRows) {
      r.dispose();
    }
    super.dispose();
  }

  String get _titleText => (_titleCtrl?.text ?? _titleInitial).trim();

  void _prefill() {
    if (_prefilled || !widget.isEditing) return;
    final list = ref.read(allTransactionsProvider).asData?.value;
    if (list == null) return;
    for (final t in list) {
      if (t.id == widget.transactionId) {
        _amount.text = centsToInput(t.amountCents);
        _titleInitial = t.title;
        _note.text = t.note;
        _type = t.type;
        _date = t.occurredOn;
        _categoryId = t.categoryId;
        _transferTargetId = t.transferAccountId;
        _accountId = t.accountId;
        _receiptPath = t.receiptPath;
        _tags = List.of(t.tags);
        if (_receiptPath != null) {
          _receiptUrlFuture =
              ref.read(receiptStorageProvider).signedUrl(_receiptPath!);
        }
        _prefilled = true;
        break;
      }
    }
  }

  /// Beim Bearbeiten vorhandene Aufteilungen laden (sobald der Stream da ist).
  void _prefillSplits() {
    if (_splitsPrefilled) return;
    final data = ref.read(allSplitsProvider).asData;
    if (data == null) return; // noch nicht geladen → später erneut
    final mine =
        data.value.where((s) => s.transactionId == widget.transactionId);
    if (mine.isNotEmpty) {
      _splitMode = true;
      for (final s in mine) {
        _splitRows.add(_SplitRow(
          categoryId: s.categoryId,
          amount: centsToInput(s.amountCents),
        ));
      }
    }
    _splitsPrefilled = true;
  }

  void _addSplitRow({String? categoryId, String amount = ''}) {
    setState(() => _splitRows
        .add(_SplitRow(categoryId: categoryId, amount: amount)));
  }

  void _removeSplitRow(int i) {
    setState(() => _splitRows.removeAt(i).dispose());
  }

  int get _splitSumCents {
    var sum = 0;
    for (final r in _splitRows) {
      sum += parseToCents(r.amountCtrl.text) ?? 0;
    }
    return sum;
  }

  void _onTitleSelected(String selected) => _applyAutoCategory(selected);

  /// Setzt automatisch eine Kategorie: erst Regeln (Stichwort enthalten),
  /// dann die zuletzt für genau diesen Titel verwendete Kategorie.
  void _applyAutoCategory(String title) {
    if (_type == TransactionType.transfer || _categoryId != null) return;
    final t = title.trim().toLowerCase();
    if (t.isEmpty) return;
    final rules = ref.read(categoryRulesProvider).asData?.value ?? const [];
    for (final r in rules) {
      if (r.keyword.isNotEmpty && t.contains(r.keyword.toLowerCase())) {
        setState(() => _categoryId = r.categoryId);
        return;
      }
    }
    final suggestion = ref.read(titleCategoryProvider)[t];
    if (suggestion != null) setState(() => _categoryId = suggestion);
  }

  String get _backTarget =>
      widget.accountId != null ? '/account/${widget.accountId}' : '/transactions';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    // Re-Entry-Schutz: verhindert doppelte Buchungen bei schnellem Doppel-Tipp
    // (der Button-Disable greift erst nach dem Rebuild – diese Sperre sofort).
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    final cents = parseToCents(_amount.text);
    if (cents == null || cents <= 0) return;
    final l = AppLocalizations.of(context);
    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.chooseAccount)),
      );
      return;
    }
    if (_type == TransactionType.transfer && _transferTargetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.chooseTargetAccount)),
      );
      return;
    }
    // Aufteilungen vorbereiten/prüfen (nur bei Ausgabe/Einnahme).
    var splitActive = _splitMode && _type != TransactionType.transfer;
    var splitData = <({String? categoryId, int amountCents, String note})>[];
    if (splitActive) {
      splitData = [
        for (final r in _splitRows)
          if ((parseToCents(r.amountCtrl.text) ?? 0) > 0)
            (
              categoryId: r.categoryId,
              amountCents: parseToCents(r.amountCtrl.text)!,
              note: '',
            ),
      ];
      if (splitData.isEmpty) {
        splitActive = false; // nichts verteilt → wie normale Buchung
      } else {
        final sum = splitData.fold<int>(0, (s, e) => s + e.amountCents);
        if (sum != cents) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                l.splitSumMismatch(formatCents(sum), formatCents(cents))),
          ));
          return;
        }
      }
    }
    final categoryToSave = splitActive ? null : _categoryId;

    setState(() => _saving = true);
    final repo = ref.read(transactionRepositoryProvider);
    final splitRepo = ref.read(splitRepositoryProvider);
    try {
      String txId;
      if (widget.isEditing) {
        await repo.updateTransaction(
          id: widget.transactionId!,
          accountId: _accountId!,
          type: _type,
          amountCents: cents,
          occurredOn: _date,
          title: _titleText,
          note: _note.text.trim(),
          categoryId: categoryToSave,
          transferAccountId: _transferTargetId,
          receiptPath: _receiptPath,
          tags: _tags,
        );
        txId = widget.transactionId!;
      } else {
        txId = await repo.addTransaction(
          accountId: _accountId!,
          type: _type,
          amountCents: cents,
          occurredOn: _date,
          title: _titleText,
          note: _note.text.trim(),
          categoryId: categoryToSave,
          transferAccountId: _transferTargetId,
          receiptPath: _receiptPath,
          tags: _tags,
        );
      }
      if (splitActive) {
        await splitRepo.replaceForTransaction(txId, splitData);
      } else if (widget.isEditing) {
        await splitRepo.deleteForTransaction(txId);
      }
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(allSplitsProvider);
      if (mounted) context.go(_backTarget);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorWith(e))));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.deleteTransactionTitle),
        content: Text(l.cannotUndo),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref
        .read(transactionRepositoryProvider)
        .deleteTransaction(widget.transactionId!);
    await ref
        .read(splitRepositoryProvider)
        .deleteForTransaction(widget.transactionId!);
    ref.invalidate(allTransactionsProvider);
    ref.invalidate(allSplitsProvider);
    if (mounted) context.go(_backTarget);
  }

  Future<void> _showHistory() async {
    final l = AppLocalizations.of(context);
    final repo = ref.read(transactionRepositoryProvider);
    final names =
        ref.read(profileNamesProvider).asData?.value ?? const <String, String>{};
    final df = DateFormat('dd.MM.yyyy HH:mm');
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => FutureBuilder<List<AuditEntry>>(
        future: repo.historyFor(widget.transactionId!),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const SizedBox(
                height: 160, child: Center(child: CircularProgressIndicator()));
          }
          final items = snap.data!;
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(l.history,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.noHistory),
                  ),
                for (final e in items)
                  ListTile(
                    dense: true,
                    leading: Icon(switch (e.action) {
                      'insert' => Icons.add_circle_outline,
                      'delete' => Icons.delete_outline,
                      'restore' => Icons.restore,
                      'purge' => Icons.delete_forever,
                      _ => Icons.edit_outlined,
                    }),
                    title: Text(l.auditAction(e.action)),
                    subtitle: Text(
                        '${names[e.actor] ?? l.unknownPerson} · ${df.format(e.at.toLocal())}'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _saveAsTemplate() async {
    final l = AppLocalizations.of(context);
    final nameCtrl = TextEditingController(text: _titleText);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.saveAsTemplate),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(labelText: l.templateNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(templateRepositoryProvider).add(
          name: name,
          accountId: _accountId,
          type: _type,
          amountCents: parseToCents(_amount.text) ?? 0,
          categoryId: _categoryId,
          title: _titleText,
          note: _note.text.trim(),
          tags: _tags,
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.templateSaved)),
      );
    }
  }

  Future<void> _pickTemplate() async {
    final l = AppLocalizations.of(context);
    final chosen = await showModalBottomSheet<TransactionTemplate>(
      context: context,
      builder: (ctx) => Consumer(
        builder: (ctx, ref2, _) {
          final templates =
              ref2.watch(templatesProvider).asData?.value ?? const [];
          return SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                ListTile(
                  title: Text(l.chooseTemplate),
                  dense: true,
                ),
                if (templates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(l.noTemplates),
                  ),
                for (final t in templates)
                  ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(t.name),
                    subtitle: Text(formatCents(t.amountCents)),
                    onTap: () => Navigator.pop(ctx, t),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          ref2.read(templateRepositoryProvider).delete(t.id),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
    if (chosen != null) _applyTemplate(chosen);
  }

  void _applyTemplate(TransactionTemplate t) {
    setState(() {
      _type = t.type;
      if (t.accountId != null) _accountId = t.accountId;
      _amount.text = t.amountCents > 0 ? centsToInput(t.amountCents) : '';
      _categoryId = t.categoryId;
      _titleInitial = t.title;
      _titleCtrl?.text = t.title;
      _note.text = t.note;
      _tags = [...t.tags];
      _splitMode = false;
    });
  }

  /// Legt eine Kopie der aktuellen Buchung an und öffnet sie zum Bearbeiten.
  Future<void> _duplicate() async {
    if (_saving) return; // Re-Entry-Schutz gegen Doppel-Anlage
    final l = AppLocalizations.of(context);
    final cents = parseToCents(_amount.text);
    if (cents == null || cents <= 0 || _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.enterValidValuesFirst)),
      );
      return;
    }
    final splitActive = _splitMode && _type != TransactionType.transfer;
    final splitData = <({String? categoryId, int amountCents, String note})>[];
    if (splitActive) {
      for (final r in _splitRows) {
        final c = parseToCents(r.amountCtrl.text) ?? 0;
        if (c > 0) {
          splitData.add((categoryId: r.categoryId, amountCents: c, note: ''));
        }
      }
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(transactionRepositoryProvider);
      final newId = await repo.addTransaction(
        accountId: _accountId!,
        type: _type,
        amountCents: cents,
        occurredOn: _date,
        title: _titleText,
        note: _note.text.trim(),
        categoryId: splitActive ? null : _categoryId,
        transferAccountId: _transferTargetId,
        tags: _tags,
      );
      if (splitData.isNotEmpty) {
        await ref
            .read(splitRepositoryProvider)
            .replaceForTransaction(newId, splitData);
      }
      ref.invalidate(allTransactionsProvider);
      ref.invalidate(allSplitsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.transactionDuplicated)),
        );
        context.go('/transactions/$newId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l.errorWith(e))));
      }
    }
  }

  Future<ImageSource?> _chooseSource() {
    final l = AppLocalizations.of(context);
    // Kamera auf Handy UND im Web/PWA (Browser-Kamera). Nur Desktop kann nicht.
    final canCamera = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    return showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (canCamera)
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(l.cameraTakePhoto),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l.galleryFile),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReceipt() async {
    final source = await _chooseSource();
    if (source == null) return;
    try {
      final x = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 70,
      );
      if (x == null) return;
      setState(() => _receiptBusy = true);
      final bytes = await x.readAsBytes();
      final ext = x.name.contains('.') ? x.name.split('.').last : 'jpg';
      // Vor dem Upload verkleinern (spart Storage; siehe image_compress.dart).
      final compressed = await compressReceipt(bytes, ext);
      final path = await ref
          .read(receiptStorageProvider)
          .upload(compressed.bytes, compressed.extension);
      if (!mounted) return;
      setState(() {
        _receiptPath = path;
        _receiptUrlFuture = ref.read(receiptStorageProvider).signedUrl(path);
        _receiptBusy = false;
      });
      // Beleg-Text erkennen (nur Android) und leere Felder vorbefüllen.
      await _tryOcrPrefill(compressed.bytes, compressed.extension);
    } catch (e) {
      if (mounted) {
        setState(() => _receiptBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context).receiptError(e))));
      }
    }
  }

  /// Liest den Beleg per On-Device-OCR (nur Android) und füllt NUR leere Felder
  /// vor (Betrag/Titel; Datum nur bei neuer Buchung). Fehler werden still
  /// verschluckt – der Beleg bleibt in jedem Fall angehängt.
  Future<void> _tryOcrPrefill(Uint8List bytes, String ext) async {
    if (!ocrSupported) return;
    final scan = await scanReceipt(bytes, ext);
    if (scan == null || !mounted) return;
    final l = AppLocalizations.of(context);
    final filled = <String>[];
    setState(() {
      if (scan.amountCents != null && (parseToCents(_amount.text) ?? 0) <= 0) {
        _amount.text = centsToInput(scan.amountCents!);
        filled.add(l.fieldAmount);
      }
      if (scan.merchant != null && _titleText.isEmpty) {
        _titleInitial = scan.merchant!;
        _titleCtrl?.text = scan.merchant!;
        filled.add(l.fieldTitle);
      }
      if (scan.date != null && !widget.isEditing) {
        _date = scan.date!;
        filled.add(l.fieldDate);
      }
    });
    if (scan.merchant != null) _applyAutoCategory(scan.merchant!);
    if (filled.isNotEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l.receiptRecognized(filled.join(', '))),
      ));
    }
  }

  Future<void> _removeReceipt() async {
    final path = _receiptPath;
    if (path == null) return;
    setState(() {
      _receiptPath = null;
      _receiptUrlFuture = null;
    });
    try {
      await ref.read(receiptStorageProvider).delete(path);
    } catch (_) {
      // Beleg bleibt evtl. im Storage; Referenz ist entfernt.
    }
  }

  Widget _buildReceiptSection(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_receiptBusy) {
      return const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_receiptPath != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child:
                Text(l.receipt, style: Theme.of(context).textTheme.labelLarge),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: FutureBuilder<String>(
              future: _receiptUrlFuture,
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: const CircularProgressIndicator(),
                  );
                }
                return Image.network(
                  snap.data!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    height: 160,
                    alignment: Alignment.center,
                    child: Text(l.receiptLoadFailed),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickReceipt,
                icon: const Icon(Icons.refresh),
                label: Text(l.replace),
              ),
              TextButton.icon(
                onPressed: _removeReceipt,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.remove),
              ),
            ],
          ),
        ],
      );
    }
    return OutlinedButton.icon(
      onPressed: _pickReceipt,
      icon: const Icon(Icons.attach_file),
      label: Text(l.addReceipt),
    );
  }

  void _fillRestIntoLastRow(int rest) {
    if (_splitRows.isEmpty) {
      _addSplitRow(amount: centsToInput(rest));
      return;
    }
    final last = _splitRows.last;
    final cur = parseToCents(last.amountCtrl.text) ?? 0;
    last.amountCtrl.text = centsToInput(cur + rest);
    setState(() {});
  }

  Widget _buildSplitEditor(BuildContext context, List<Category> categories) {
    final l = AppLocalizations.of(context);
    final total = parseToCents(_amount.text) ?? 0;
    final sum = _splitSumCents;
    final rest = total - sum;
    final balanced = total > 0 && rest == 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < _splitRows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String?>(
                    initialValue: categories
                            .any((c) => c.id == _splitRows[i].categoryId)
                        ? _splitRows[i].categoryId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                        labelText: l.category, isDense: true),
                    items: [
                      DropdownMenuItem<String?>(
                          value: null, child: Text(l.none)),
                      for (final c in categories)
                        DropdownMenuItem<String?>(
                          value: c.id,
                          child: Row(
                            children: [
                              Icon(iconForToken(c.icon), size: 18),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(c.name,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                    ],
                    onChanged: (v) =>
                        setState(() => _splitRows[i].categoryId = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _splitRows[i].amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                        labelText: l.amount, isDense: true, prefixText: '€ '),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                IconButton(
                  tooltip: l.removeRow,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _splitRows.length <= 1
                      ? null
                      : () => _removeSplitRow(i),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton.icon(
              onPressed: () => _addSplitRow(),
              icon: const Icon(Icons.add),
              label: Text(l.rowLabel),
            ),
            if (rest != 0 && total > 0)
              TextButton.icon(
                onPressed: () => _fillRestIntoLastRow(rest),
                icon: const Icon(Icons.bolt),
                label: Text(l.rest(formatCents(rest))),
              ),
          ],
        ),
        Text(
          balanced
              ? l.distributedBalanced(formatCents(sum))
              : l.distributedOf(formatCents(sum), formatCents(total),
                  formatCents(rest)),
          style: TextStyle(
            color: balanced
                ? Colors.green.shade700
                : Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _prefill();
    // Lädt beim Bearbeiten vorhandene Aufteilungen, sobald der Stream da ist.
    ref.watch(allSplitsProvider);
    _prefillSplits();
    final l = AppLocalizations.of(context);
    final df = DateFormat('dd.MM.yyyy');
    final isTransfer = _type == TransactionType.transfer;

    final accounts = (ref.watch(accountsProvider).asData?.value ??
            const <Account>[])
        .where((a) => !a.archived)
        .toList();
    _accountId ??= accounts.isNotEmpty ? accounts.first.id : null;
    if (_accountId != null && !accounts.any((a) => a.id == _accountId)) {
      _accountId = accounts.isNotEmpty ? accounts.first.id : null;
    }

    final categories = (ref.watch(categoriesProvider).asData?.value ??
            const <Category>[])
        .where((c) => c.active && c.matches(_type))
        .toList();
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) {
      _categoryId = null;
    }

    final targets = accounts.where((a) => a.id != _accountId).toList();
    if (_transferTargetId != null &&
        !targets.any((a) => a.id == _transferTargetId)) {
      _transferTargetId = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? l.editTransaction : l.newTransaction),
        actions: [
          IconButton(
            tooltip: l.saveAsTemplate,
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: _saving ? null : _saveAsTemplate,
          ),
          if (widget.isEditing)
            IconButton(
              tooltip: l.history,
              icon: const Icon(Icons.history),
              onPressed: _showHistory,
            ),
          if (widget.isEditing)
            IconButton(
              tooltip: l.duplicate,
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: _saving ? null : _duplicate,
            ),
          if (widget.isEditing)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: accounts.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(l.createAccountFirst),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.isEditing) ...[
                      OutlinedButton.icon(
                        onPressed: _pickTemplate,
                        icon: const Icon(Icons.bookmarks_outlined),
                        label: Text(l.fromTemplate),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SegmentedButton<TransactionType>(
                      segments: [
                        ButtonSegment(
                          value: TransactionType.expense,
                          label: Text(l.transactionType(TransactionType.expense)),
                          icon: const Icon(Icons.north_east),
                        ),
                        ButtonSegment(
                          value: TransactionType.income,
                          label: Text(l.transactionType(TransactionType.income)),
                          icon: const Icon(Icons.south_west),
                        ),
                        ButtonSegment(
                          value: TransactionType.transfer,
                          label:
                              Text(l.transactionType(TransactionType.transfer)),
                          icon: const Icon(Icons.swap_horiz),
                        ),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() => _type = s.first),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: l.accountLabel,
                        prefixIcon: const Icon(
                            Icons.account_balance_wallet_outlined),
                      ),
                      items: [
                        for (final a in accounts)
                          DropdownMenuItem(value: a.id, child: Text(a.name)),
                      ],
                      onChanged: (v) => setState(() => _accountId = v),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _amount,
                      autofocus: !widget.isEditing,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: l.amountHintLabel,
                        prefixIcon: const Icon(Icons.euro),
                        suffixIcon: IconButton(
                          tooltip: l.calculator,
                          icon: const Icon(Icons.calculate_outlined),
                          onPressed: () async {
                            final r = await showCalculatorSheet(context,
                                initial: _amount.text);
                            if (r != null) setState(() => _amount.text = r);
                          },
                        ),
                      ),
                      validator: (v) {
                        final c = parseToCents(v ?? '');
                        if (c == null || c <= 0) {
                          return l.enterValidAmount;
                        }
                        return null;
                      },
                    ),
                    Builder(builder: (context) {
                      final t = _amount.text;
                      final hasOp = t.contains('+') ||
                          t.contains('*') ||
                          t.contains('/') ||
                          t.lastIndexOf('-') > 0;
                      final cents = hasOp ? parseToCents(t) : null;
                      if (cents == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6, left: 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '= ${formatCents(cents)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    if (isTransfer)
                      DropdownButtonFormField<String?>(
                        initialValue: _transferTargetId,
                        decoration: InputDecoration(
                          labelText: l.targetAccount,
                          prefixIcon: const Icon(Icons.swap_horiz),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(l.chooseDash),
                          ),
                          for (final a in targets)
                            DropdownMenuItem<String?>(
                                value: a.id, child: Text(a.name)),
                        ],
                        onChanged: (v) =>
                            setState(() => _transferTargetId = v),
                      )
                    else ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _splitMode,
                        onChanged: (v) => setState(() {
                          _splitMode = v;
                          if (v && _splitRows.isEmpty) {
                            final cents = parseToCents(_amount.text) ?? 0;
                            _splitRows.add(_SplitRow(
                              categoryId: _categoryId,
                              amount: cents > 0 ? centsToInput(cents) : '',
                            ));
                          }
                        }),
                        title: Text(l.splitMultiple),
                        secondary: const Icon(Icons.call_split),
                      ),
                      if (_splitMode)
                        _buildSplitEditor(context, categories)
                      else
                        DropdownButtonFormField<String?>(
                          initialValue: _categoryId,
                          decoration: InputDecoration(
                            labelText: l.category,
                            prefixIcon: const Icon(Icons.label_outline),
                          ),
                          items: [
                            DropdownMenuItem<String?>(
                              value: null,
                              child: Text(l.noCategoryOption),
                            ),
                            for (final c in categories)
                              DropdownMenuItem<String?>(
                                value: c.id,
                                child: Row(
                                  children: [
                                    Icon(iconForToken(c.icon), size: 20),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(c.name,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (v) => setState(() => _categoryId = v),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _titleInitial),
                      optionsBuilder: (value) {
                        final q = value.text.trim().toLowerCase();
                        if (q.isEmpty) return const Iterable<String>.empty();
                        return ref
                            .read(titleSuggestionsProvider)
                            .where((s) => s.toLowerCase().contains(q))
                            .take(8);
                      },
                      onSelected: _onTitleSelected,
                      fieldViewBuilder:
                          (context, controller, focusNode, onSubmit) {
                        _titleCtrl = controller;
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: _applyAutoCategory,
                          decoration: InputDecoration(
                            labelText: l.titleHintLabel,
                            prefixIcon: const Icon(Icons.storefront_outlined),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _note,
                      minLines: 3,
                      maxLines: 6,
                      decoration: InputDecoration(
                        labelText: l.note,
                        alignLabelWithHint: true,
                        prefixIcon: const Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TagEditor(
                      tags: _tags,
                      suggestions: ref.watch(allTagsProvider),
                      onChanged: (t) => setState(() => _tags = t),
                    ),
                    const SizedBox(height: 16),
                    _buildReceiptSection(context),
                    const SizedBox(height: 16),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      leading: const Icon(Icons.calendar_today),
                      title: Text(l.dateLabel),
                      subtitle: Text(df.format(_date)),
                      trailing: const Icon(Icons.edit_calendar),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(l.save),
                    ),
                    if (widget.isEditing) ...[
                      const SizedBox(height: 24),
                      const Divider(),
                      const SizedBox(height: 8),
                      CommentsSection(transactionId: widget.transactionId!),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// Eine Zeile im Split-Editor (Kategorie + Betrag).
class _SplitRow {
  _SplitRow({this.categoryId, String amount = ''})
      : amountCtrl = TextEditingController(text: amount);

  String? categoryId;
  final TextEditingController amountCtrl;

  void dispose() => amountCtrl.dispose();
}
