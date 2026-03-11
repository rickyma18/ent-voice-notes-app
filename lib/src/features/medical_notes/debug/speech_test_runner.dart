import 'transcript_qa_harness.dart';

Future<void> runSpeechTest({
  required String transcript,
  String scope = 'full',
}) async {
  await runTranscriptHarness(scope: scope, transcript: transcript);
}

