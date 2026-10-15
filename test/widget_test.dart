import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tempo/main.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('TempoApp initial smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: TempoApp()));
    await tester.pump(const Duration(milliseconds: 500));

    // Verify brand title is visible
    expect(find.text('TEMPO.'), findsOneWidget);
    expect(find.text('OS'), findsOneWidget);

    // Verify main navigation destinations
    expect(find.text('Bugün'), findsOneWidget);
    expect(find.text('Bütçeler'), findsOneWidget);
    expect(find.text('Havuz'), findsOneWidget);
    expect(find.text('Analiz'), findsOneWidget);
  });
}
