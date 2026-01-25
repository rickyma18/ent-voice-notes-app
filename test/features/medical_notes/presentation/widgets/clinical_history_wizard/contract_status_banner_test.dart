import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/presentation/widgets/clinical_history_wizard/contract_status_banner.dart';

void main() {
  group('ContractStatusBanner', () {
    testWidgets('renders nothing when status is null or ok', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ContractStatusBanner(status: null)),
        ),
      );
      expect(find.byType(Container), findsNothing);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ContractStatusBanner(status: 'ok')),
        ),
      );
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders yellow banner for warning status', (tester) async {
      const warnings = ['Warning 1', 'Warning 2'];
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContractStatusBanner(status: 'warning', warnings: warnings),
          ),
        ),
      );

      expect(find.text('Advertencia de contrato'), findsOneWidget);
      expect(find.text('• Warning 1'), findsOneWidget);
      expect(find.text('• Warning 2'), findsOneWidget);

      // Check colors (approximate check by finding Icon with specific color in tree if needed,
      // but text finding is usually sufficient for presence).
      final iconFinder = find.byIcon(Icons.info_outline);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('renders orange banner for drift status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ContractStatusBanner(status: 'drift')),
        ),
      );

      expect(find.text('Posible cambio en el modelo (Drift)'), findsOneWidget);
      final iconFinder = find.byIcon(Icons.warning_amber_rounded);
      expect(iconFinder, findsOneWidget);
    });

    testWidgets('renders nothing for unknown status', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ContractStatusBanner(status: 'unknown_status')),
        ),
      );
      expect(find.byType(Container), findsNothing);
    });

    testWidgets('renders banner even if warnings is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ContractStatusBanner(
              status: 'warning',
              warnings: null, // explicit null
            ),
          ),
        ),
      );

      expect(find.text('Advertencia de contrato'), findsOneWidget);
      // specific warnings shouldn't exist
      expect(find.textContaining('•'), findsNothing);
    });
  });
}
