import 'dart:io';
import 'package:test/test.dart';
import '../bin/run_eval.dart';

void main() {
  test('Harness Replay Mode runs and writes report.json', () async {
    final code = await runEvalHarness(['--mode=replay']);

    // En baseline actual puede ser 0 o 1 según quality. Aquí solo smoke.
    expect(code, anyOf(0, 1));

    // Debe generar reporte.
    final report = File('output/report.json');
    expect(await report.exists(), isTrue);
    expect(await report.length(), greaterThan(10));
  });
}
