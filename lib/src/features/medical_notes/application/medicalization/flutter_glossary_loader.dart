// lib/src/features/medical_notes/application/medicalization/flutter_glossary_loader.dart
//
// Flutter-specific implementation using rootBundle.
// Used when running in the Flutter app context.

import 'package:flutter/services.dart' show rootBundle;

import 'glossary_loader.dart';

/// Flutter implementation of [GlossaryLoader] using rootBundle.
///
/// This is the default loader for the Flutter app.
class FlutterGlossaryLoader extends GlossaryLoader {
  const FlutterGlossaryLoader({
    this.assetPath =
        'lib/src/features/medical_notes/resources/medical_lexicon/colloquial_to_clinical_es.json',
  });

  final String assetPath;

  @override
  Future<String> loadJsonString() async {
    return rootBundle.loadString(assetPath);
  }
}
