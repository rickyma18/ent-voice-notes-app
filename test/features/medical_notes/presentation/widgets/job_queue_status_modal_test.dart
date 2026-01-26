import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_notes_app/src/features/medical_notes/data/medgemma/clients/medgemma_client.dart';
import 'package:medical_notes_app/src/features/medical_notes/presentation/controllers/job_queue_controller.dart';
import 'package:medical_notes_app/src/features/medical_notes/presentation/widgets/job_queue_status_modal.dart';

// Mock that extends the real controller (works because .g.dart exists)
class MockJobQueueController extends JobQueueController {
  // We can ignore the build() override since we'll set state directly
  // or via a helper if needed, but for Notifiers, we usually just use the
  // container to set state if we can, or we implement build to return a specific value.

  // Ideally we mock the build method to return our initial state
  // But strictly speaking, overrideWith(() => Mock()) uses the Mock's build.

  final AsyncValue<JobStatusResponse?> _initialState;

  MockJobQueueController({AsyncValue<JobStatusResponse?>? initialState})
    : _initialState = initialState ?? const AsyncValue.data(null);

  @override
  AsyncValue<JobStatusResponse?> build() {
    return _initialState;
  }

  void setState(AsyncValue<JobStatusResponse?> newState) {
    state = newState;
  }
}

void main() {
  testWidgets(
    'JobQueueStatusModal shows fallback warning when fallbackUsed=true',
    (tester) async {
      // Arrange
      final mockController = MockJobQueueController(
        initialState: const AsyncValue.data(
          JobStatusResponse(
            success: true,
            status: 'done',
            fallbackUsed: true,
            result: {},
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          jobQueueControllerProvider.overrideWith(() => mockController),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: JobQueueStatusModal())),
        ),
      );

      // Act
      await tester.pump();

      // Assert
      expect(find.text('Procesando nota...'), findsOneWidget);
      expect(find.textContaining('Se usó un modo de respaldo'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    },
  );

  testWidgets(
    'JobQueueStatusModal does NOT show fallback warning when fallbackUsed=false',
    (tester) async {
      // Arrange
      final mockController = MockJobQueueController(
        initialState: const AsyncValue.data(
          JobStatusResponse(
            success: true,
            status: 'done',
            fallbackUsed: false,
            result: {},
          ),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          jobQueueControllerProvider.overrideWith(() => mockController),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: JobQueueStatusModal())),
        ),
      );

      // Act
      await tester.pump();

      // Assert
      expect(find.textContaining('Se usó un modo de respaldo'), findsNothing);
    },
  );
}
