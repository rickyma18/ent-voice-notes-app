import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/core/utility/validation/validation.dart';
import 'package:medical_notes_app/src/ui/widgets/docsoft_input.dart';

void main() {
  group('DocsoftInput with InputFormatters', () {
    testWidgets('name formatter enforces 60 character limit on typing', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocsoftInput(
              controller: controller,
              label: 'Nombre completo',
              inputFormatters: InputFormatters.name,
            ),
          ),
        ),
      );

      // Find the text field
      final textField = find.byType(TextFormField);
      expect(textField, findsOneWidget);

      // Try to enter 100 characters (way more than 60 limit)
      final longText = 'a' * 100;
      await tester.enterText(textField, longText);
      await tester.pump();

      // Verify the controller text is truncated to 60 characters
      expect(
        controller.text.length,
        equals(60),
        reason:
            'Controller should have exactly 60 characters, not ${controller.text.length}',
      );
      expect(controller.text, equals('a' * 60));
    });

    testWidgets('name formatter enforces 60 character limit on paste', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DocsoftInput(
              controller: controller,
              label: 'Nombre completo',
              inputFormatters: InputFormatters.name,
            ),
          ),
        ),
      );

      // Find the text field
      final textField = find.byType(TextFormField);

      // Simulate pasting 100 characters
      final longText =
          'María García López Hernández Rodríguez Fernández Martínez Gómez Díaz Pérez';
      await tester.enterText(textField, longText);
      await tester.pump();

      // Verify the controller text is truncated to max 60 characters
      expect(
        controller.text.length,
        lessThanOrEqualTo(60),
        reason:
            'Controller should have at most 60 characters, not ${controller.text.length}',
      );
    });

    testWidgets('LengthLimitingTextInputFormatter works directly', (
      tester,
    ) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(
              controller: controller,
              inputFormatters: [LengthLimitingTextInputFormatter(60)],
            ),
          ),
        ),
      );

      // Find the text field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);

      // Try to enter 100 characters
      final longText = 'x' * 100;
      await tester.enterText(textField, longText);
      await tester.pump();

      // Verify the controller text is truncated to 60 characters
      expect(
        controller.text.length,
        equals(60),
        reason:
            'Direct TextField should have exactly 60 characters, not ${controller.text.length}',
      );
    });

    testWidgets('InputFormatters.name contains correct formatters', (
      tester,
    ) async {
      final formatters = InputFormatters.name;

      // Should have 2 formatters: LengthLimiting and Filtering
      expect(formatters.length, equals(2));

      // First should be LengthLimitingTextInputFormatter
      expect(formatters[0], isA<LengthLimitingTextInputFormatter>());
      final lengthFormatter = formatters[0] as LengthLimitingTextInputFormatter;
      expect(lengthFormatter.maxLength, equals(60));

      // Second should be FilteringTextInputFormatter
      expect(formatters[1], isA<FilteringTextInputFormatter>());
    });

    testWidgets(
      'name formatter enforces limit when building up text progressively',
      (tester) async {
        final controller = TextEditingController();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: DocsoftInput(
                controller: controller,
                label: 'Nombre completo',
                inputFormatters: InputFormatters.name,
              ),
            ),
          ),
        );

        final textField = find.byType(TextFormField);
        await tester.tap(textField);
        await tester.pump();

        // Simulate progressively typing characters one by one
        // This mimics real user behavior more closely
        String currentText = '';
        for (int i = 0; i < 70; i++) {
          currentText += 'g';
          await tester.enterText(textField, currentText);
          await tester.pump();

          // The controller should never exceed 60 chars
          if (controller.text.length > 60) {
            fail(
              'Controller exceeded 60 chars at iteration $i: ${controller.text.length} chars',
            );
          }
        }

        // Final check: should be exactly 60
        expect(
          controller.text.length,
          equals(60),
          reason: 'After typing 70 g chars, controller should have exactly 60',
        );
      },
    );
  });
}
