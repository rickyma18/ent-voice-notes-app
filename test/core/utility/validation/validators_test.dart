import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/core/utility/validation/validation.dart';

void main() {
  group('InputRules', () {
    test('nameRegex allows valid names', () {
      expect(InputRules.nameRegex.hasMatch('John'), isTrue);
      expect(InputRules.nameRegex.hasMatch('María'), isTrue);
      expect(InputRules.nameRegex.hasMatch('José Luis'), isTrue);
      expect(InputRules.nameRegex.hasMatch("O'Connor"), isTrue);
      expect(InputRules.nameRegex.hasMatch('García-López'), isTrue);
      expect(InputRules.nameRegex.hasMatch('Ñoño'), isTrue);
    });

    test('nameRegex rejects invalid names', () {
      expect(InputRules.nameRegex.hasMatch('John123'), isFalse);
      expect(InputRules.nameRegex.hasMatch('Test@email'), isFalse);
      expect(InputRules.nameRegex.hasMatch('Name#1'), isFalse);
    });

    test('phoneRegex allows valid phones', () {
      expect(InputRules.phoneRegex.hasMatch('+52 555 123 4567'), isTrue);
      expect(InputRules.phoneRegex.hasMatch('5551234567'), isTrue);
      expect(InputRules.phoneRegex.hasMatch('(555) 123-4567'), isTrue);
    });

    test('phoneRegex rejects invalid phones', () {
      expect(InputRules.phoneRegex.hasMatch('abc123'), isFalse);
      expect(InputRules.phoneRegex.hasMatch('phone@test'), isFalse);
    });

    test('age constants are valid', () {
      expect(InputRules.ageMin, equals(0));
      expect(InputRules.ageMax, equals(120));
      expect(InputRules.ageMaxLength, equals(3));
    });
  });

  group('NameValidation', () {
    late NameValidation validation;

    setUp(() {
      validation = const NameValidation();
    });

    testWidgets('returns null for valid names', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, 'John'), isNull);
              expect(validation.validate(context, 'María José'), isNull);
              expect(validation.validate(context, 'García-López'), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns error for names with numbers', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, 'John123'), isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns error for too short names', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, 'A'), isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns null for empty (use RequiredValidation)', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, ''), isNull);
              expect(validation.validate(context, null), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('AgeValidation', () {
    late AgeValidation validation;

    setUp(() {
      validation = const AgeValidation();
    });

    testWidgets('returns null for valid ages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, '0'), isNull);
              expect(validation.validate(context, '25'), isNull);
              expect(validation.validate(context, '120'), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns error for invalid ages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, '-1'), isNotNull);
              expect(validation.validate(context, '121'), isNotNull);
              expect(validation.validate(context, 'abc'), isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns null for empty (optional)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, ''), isNull);
              expect(validation.validate(context, null), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('PhoneValidation', () {
    late PhoneValidation validation;

    setUp(() {
      validation = const PhoneValidation();
    });

    testWidgets('returns null for valid phones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, '+52 555 123 4567'), isNull);
              expect(validation.validate(context, '5551234567'), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns error for too short phones', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, '123'), isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns null for empty (optional by default)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(validation.validate(context, ''), isNull);
              expect(validation.validate(context, null), isNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });

    testWidgets('returns error for empty when required', (tester) async {
      final requiredValidation = const PhoneValidation(required: true);
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              expect(requiredValidation.validate(context, ''), isNotNull);
              return const SizedBox();
            },
          ),
        ),
      );
    });
  });

  group('InputFormatters', () {
    test('name formatters are not empty', () {
      expect(InputFormatters.name, isNotEmpty);
    });

    test(
      'name formatters include LengthLimitingTextInputFormatter with correct value',
      () {
        final formatters = InputFormatters.name;

        // Find the LengthLimitingTextInputFormatter
        final lengthFormatter = formatters
            .whereType<LengthLimitingTextInputFormatter>()
            .firstOrNull;
        expect(
          lengthFormatter,
          isNotNull,
          reason:
              'InputFormatters.name should include LengthLimitingTextInputFormatter',
        );

        // Verify it uses the correct max length
        expect(
          lengthFormatter!.maxLength,
          equals(InputRules.nameMaxLength),
          reason:
              'LengthLimitingTextInputFormatter should use InputRules.nameMaxLength (${InputRules.nameMaxLength})',
        );
      },
    );

    test('name formatter enforces 60 character limit', () {
      final formatters = InputFormatters.name;
      final lengthFormatter = formatters
          .whereType<LengthLimitingTextInputFormatter>()
          .first;

      // Verify the actual max length value
      expect(lengthFormatter.maxLength, equals(60));
    });

    test('age formatters are not empty', () {
      expect(InputFormatters.age, isNotEmpty);
    });

    test('phone formatters are not empty', () {
      expect(InputFormatters.phone, isNotEmpty);
    });

    test('freeText formatters are not empty', () {
      expect(InputFormatters.freeText, isNotEmpty);
    });
  });
}
