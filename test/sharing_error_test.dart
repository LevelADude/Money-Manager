// Freigaben: Schlägt das Speichern am Server fehl, erscheint eine Meldung und
// die bisherige Auswahl bleibt stehen (kein Optimistic Update bei Rechten).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:money_manager/core/theme.dart';
import 'package:money_manager/data/models/access_grant.dart';
import 'package:money_manager/data/repositories/access_grant_repository.dart';
import 'package:money_manager/dev_preview.dart';
import 'package:money_manager/dev_preview_data.dart';
import 'package:money_manager/features/sharing/access_grant_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingRepo implements AccessGrantRepository {
  int calls = 0;

  @override
  Future<void> grant(String granteeId, GrantLevel level) async {
    calls++;
    throw Exception('offline');
  }

  @override
  Future<void> revoke(String granteeId) async {
    calls++;
    throw Exception('offline');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() => initializeDateFormatting('de'));

  testWidgets('Serverfehler beim Ändern zeigt Meldung, Auswahl bleibt', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _FailingRepo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...previewOverrides(prefs, now: DateTime(2026, 11, 15)),
          accessGrantRepositoryProvider.overrideWithValue(repo),
        ],
        child: const PreviewApp(
          initialLocation: '/more/sharing',
          palette: AppPalette.sage,
        ),
      ),
    );
    await tester.pumpAndSettle();

    SegmentedButton<String> button() =>
        tester.widget(find.byType(SegmentedButton<String>));
    expect(button().selected, {'view'});

    await tester.tap(find.text('Verwalten'));
    await tester.pumpAndSettle();

    expect(repo.calls, 1);
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    expect(button().selected, {'view'});
  });
}
