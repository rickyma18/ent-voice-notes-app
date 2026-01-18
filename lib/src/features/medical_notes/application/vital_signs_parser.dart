// lib/src/features/medical_notes/application/vital_signs_parser.dart

/// Parsed vital signs from a transcript.
///
/// All fields are nullable - only set if successfully parsed from text.
class ParsedVitalSigns {
  const ParsedVitalSigns({
    this.weightKg,
    this.heightCm,
    this.bpSystolic,
    this.bpDiastolic,
    this.heartRate,
    this.respiratoryRate,
    this.temperatureC,
    this.spo2,
    this.prognosis,
  });

  final double? weightKg;
  final double? heightCm;
  final int? bpSystolic;
  final int? bpDiastolic;
  final int? heartRate;
  final int? respiratoryRate;
  final double? temperatureC;
  final int? spo2;
  final String? prognosis;

  bool get hasAnyValue =>
      weightKg != null ||
      heightCm != null ||
      bpSystolic != null ||
      bpDiastolic != null ||
      heartRate != null ||
      respiratoryRate != null ||
      temperatureC != null ||
      spo2 != null ||
      prognosis != null;

  @override
  String toString() {
    return 'ParsedVitalSigns('
        'weightKg: $weightKg, '
        'heightCm: $heightCm, '
        'bpSystolic: $bpSystolic, '
        'bpDiastolic: $bpDiastolic, '
        'heartRate: $heartRate, '
        'respiratoryRate: $respiratoryRate, '
        'temperatureC: $temperatureC, '
        'spo2: $spo2, '
        'prognosis: $prognosis)';
  }
}

/// Regex-based parser for extracting vital signs from transcript text.
///
/// This is a deterministic parser (no ML) that recognizes common Spanish
/// medical dictation patterns for vital signs.
class VitalSignsParser {
  const VitalSignsParser._();

  /// Parses vital signs from the given transcript text.
  ///
  /// Returns a [ParsedVitalSigns] object with any values that could be extracted.
  /// Values that couldn't be parsed will be null.
  static ParsedVitalSigns parse(String transcript) {
    final text = _normalize(transcript);

    return ParsedVitalSigns(
      weightKg: _parseWeight(text),
      heightCm: _parseHeight(text),
      bpSystolic: _parseBpSystolic(text),
      bpDiastolic: _parseBpDiastolic(text),
      heartRate: _parseHeartRate(text),
      respiratoryRate: _parseRespiratoryRate(text),
      temperatureC: _parseTemperature(text),
      spo2: _parseSpo2(text),
      prognosis: _parsePrognosis(text),
    );
  }

  /// Normalizes text for parsing: lowercase, normalize accents, extra spaces.
  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .trim();
  }

  /// Parses weight in kg.
  /// Patterns: "peso 70", "peso de 70 kg", "70 kilos", "pesa 70"
  static double? _parseWeight(String text) {
    // "peso [de] X [kg|kilos|kilogramos]"
    final pesoMatch = RegExp(
      r'peso\s*(?:de\s*)?(\d+(?:[.,]\d+)?)\s*(?:kg|kilos?|kilogramos?)?',
    ).firstMatch(text);
    if (pesoMatch != null) {
      return _parseNumber(pesoMatch.group(1));
    }

    // "pesa X [kg|kilos]"
    final pesaMatch = RegExp(
      r'pesa\s*(\d+(?:[.,]\d+)?)\s*(?:kg|kilos?|kilogramos?)?',
    ).firstMatch(text);
    if (pesaMatch != null) {
      return _parseNumber(pesaMatch.group(1));
    }

    // "X kg" or "X kilos" standalone
    final kgMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:kg|kilos?|kilogramos)\b',
    ).firstMatch(text);
    if (kgMatch != null) {
      final value = _parseNumber(kgMatch.group(1));
      if (value != null && value >= 1 && value <= 300) {
        return value;
      }
    }

    return null;
  }

  /// Parses height in cm.
  /// Patterns: "talla 170", "talla 1.70", "mide 170 cm", "170 centimetros"
  static double? _parseHeight(String text) {
    // "talla [de] X [cm|centimetros|metros]"
    final tallaMatch = RegExp(
      r'talla\s*(?:de\s*)?(\d+(?:[.,]\d+)?)\s*(?:cm|centimetros?|metros?|m)?',
    ).firstMatch(text);
    if (tallaMatch != null) {
      return _parseHeightValue(tallaMatch.group(1));
    }

    // "mide X [cm|metros]"
    final mideMatch = RegExp(
      r'mide\s*(\d+(?:[.,]\d+)?)\s*(?:cm|centimetros?|metros?|m)?',
    ).firstMatch(text);
    if (mideMatch != null) {
      return _parseHeightValue(mideMatch.group(1));
    }

    // "estatura [de] X"
    final estaturaMatch = RegExp(
      r'estatura\s*(?:de\s*)?(\d+(?:[.,]\d+)?)\s*(?:cm|centimetros?|metros?|m)?',
    ).firstMatch(text);
    if (estaturaMatch != null) {
      return _parseHeightValue(estaturaMatch.group(1));
    }

    // "X cm" or "X centimetros" standalone (only if reasonable height range)
    final cmMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:cm|centimetros)\b',
    ).firstMatch(text);
    if (cmMatch != null) {
      final value = _parseNumber(cmMatch.group(1));
      if (value != null && value >= 50 && value <= 250) {
        return value;
      }
    }

    return null;
  }

  /// Converts height value, handling meters vs cm.
  static double? _parseHeightValue(String? valueStr) {
    if (valueStr == null) return null;
    final value = _parseNumber(valueStr);
    if (value == null) return null;

    // If value is small (e.g., 1.70), it's in meters - convert to cm
    if (value > 0 && value < 3) {
      return value * 100;
    }
    // Otherwise assume cm
    if (value >= 30 && value <= 250) {
      return value;
    }
    return null;
  }

  /// Parses blood pressure systolic.
  /// Patterns: "presion 120/80", "TA 120 sobre 80", "tension arterial 120/80"
  static int? _parseBpSystolic(String text) {
    final bp = _parseBloodPressure(text);
    return bp?.$1;
  }

  /// Parses blood pressure diastolic.
  static int? _parseBpDiastolic(String text) {
    final bp = _parseBloodPressure(text);
    return bp?.$2;
  }

  /// Parses blood pressure as (systolic, diastolic) tuple.
  static (int, int)? _parseBloodPressure(String text) {
    // "presion [arterial] X/Y" or "presion X sobre Y"
    final presionMatch = RegExp(
      r'presion\s*(?:arterial\s*)?(\d+)\s*[/]\s*(\d+)',
    ).firstMatch(text);
    if (presionMatch != null) {
      final sys = int.tryParse(presionMatch.group(1) ?? '');
      final dia = int.tryParse(presionMatch.group(2) ?? '');
      if (sys != null && dia != null && _isValidBp(sys, dia)) {
        return (sys, dia);
      }
    }

    // "presion X sobre Y"
    final sobreMatch = RegExp(
      r'presion\s*(?:arterial\s*)?(\d+)\s*sobre\s*(\d+)',
    ).firstMatch(text);
    if (sobreMatch != null) {
      final sys = int.tryParse(sobreMatch.group(1) ?? '');
      final dia = int.tryParse(sobreMatch.group(2) ?? '');
      if (sys != null && dia != null && _isValidBp(sys, dia)) {
        return (sys, dia);
      }
    }

    // "TA X/Y" or "ta X/Y"
    final taMatch = RegExp(r'\bta\s*(\d+)\s*[/]\s*(\d+)').firstMatch(text);
    if (taMatch != null) {
      final sys = int.tryParse(taMatch.group(1) ?? '');
      final dia = int.tryParse(taMatch.group(2) ?? '');
      if (sys != null && dia != null && _isValidBp(sys, dia)) {
        return (sys, dia);
      }
    }

    // "tension [arterial] X/Y"
    final tensionMatch = RegExp(
      r'tension\s*(?:arterial\s*)?(\d+)\s*[/]\s*(\d+)',
    ).firstMatch(text);
    if (tensionMatch != null) {
      final sys = int.tryParse(tensionMatch.group(1) ?? '');
      final dia = int.tryParse(tensionMatch.group(2) ?? '');
      if (sys != null && dia != null && _isValidBp(sys, dia)) {
        return (sys, dia);
      }
    }

    // Standalone pattern X/Y mmHg
    final mmhgMatch = RegExp(
      r'(\d+)\s*[/]\s*(\d+)\s*(?:mmhg|milimetros)',
    ).firstMatch(text);
    if (mmhgMatch != null) {
      final sys = int.tryParse(mmhgMatch.group(1) ?? '');
      final dia = int.tryParse(mmhgMatch.group(2) ?? '');
      if (sys != null && dia != null && _isValidBp(sys, dia)) {
        return (sys, dia);
      }
    }

    return null;
  }

  static bool _isValidBp(int systolic, int diastolic) {
    return systolic >= 50 &&
        systolic <= 250 &&
        diastolic >= 30 &&
        diastolic <= 150 &&
        systolic > diastolic;
  }

  /// Parses heart rate (frecuencia cardiaca / FC).
  /// Patterns: "FC 72", "frecuencia cardiaca 72", "pulso 72"
  static int? _parseHeartRate(String text) {
    // "fc X" or "f.c. X"
    final fcMatch = RegExp(
      r'\bf\.?c\.?\s*(?:de\s*)?(\d+)\s*(?:lpm|latidos)?',
    ).firstMatch(text);
    if (fcMatch != null) {
      final value = int.tryParse(fcMatch.group(1) ?? '');
      if (value != null && value >= 20 && value <= 250) {
        return value;
      }
    }

    // "frecuencia cardiaca [de] X"
    final freqMatch = RegExp(
      r'frecuencia\s*cardiaca\s*(?:de\s*)?(\d+)\s*(?:lpm|latidos)?',
    ).firstMatch(text);
    if (freqMatch != null) {
      final value = int.tryParse(freqMatch.group(1) ?? '');
      if (value != null && value >= 20 && value <= 250) {
        return value;
      }
    }

    // "pulso [de] X"
    final pulsoMatch = RegExp(
      r'pulso\s*(?:de\s*)?(\d+)\s*(?:lpm|latidos)?',
    ).firstMatch(text);
    if (pulsoMatch != null) {
      final value = int.tryParse(pulsoMatch.group(1) ?? '');
      if (value != null && value >= 20 && value <= 250) {
        return value;
      }
    }

    // "X latidos por minuto" or "X lpm"
    final lpmMatch = RegExp(
      r'(\d+)\s*(?:latidos\s*por\s*minuto|lpm)\b',
    ).firstMatch(text);
    if (lpmMatch != null) {
      final value = int.tryParse(lpmMatch.group(1) ?? '');
      if (value != null && value >= 20 && value <= 250) {
        return value;
      }
    }

    return null;
  }

  /// Parses respiratory rate (frecuencia respiratoria / FR).
  /// Patterns: "FR 16", "frecuencia respiratoria 16"
  static int? _parseRespiratoryRate(String text) {
    // "fr X" or "f.r. X"
    final frMatch = RegExp(
      r'\bf\.?r\.?\s*(?:de\s*)?(\d+)\s*(?:rpm|respiraciones)?',
    ).firstMatch(text);
    if (frMatch != null) {
      final value = int.tryParse(frMatch.group(1) ?? '');
      if (value != null && value >= 5 && value <= 80) {
        return value;
      }
    }

    // "frecuencia respiratoria [de] X"
    final freqMatch = RegExp(
      r'frecuencia\s*respiratoria\s*(?:de\s*)?(\d+)\s*(?:rpm|respiraciones)?',
    ).firstMatch(text);
    if (freqMatch != null) {
      final value = int.tryParse(freqMatch.group(1) ?? '');
      if (value != null && value >= 5 && value <= 80) {
        return value;
      }
    }

    // "X respiraciones por minuto" or "X rpm"
    final rpmMatch = RegExp(
      r'(\d+)\s*(?:respiraciones\s*por\s*minuto|rpm)\b',
    ).firstMatch(text);
    if (rpmMatch != null) {
      final value = int.tryParse(rpmMatch.group(1) ?? '');
      if (value != null && value >= 5 && value <= 80) {
        return value;
      }
    }

    return null;
  }

  /// Parses temperature in Celsius.
  /// Patterns: "temperatura 36.5", "temp 37", "37 grados"
  static double? _parseTemperature(String text) {
    // "temperatura [de] X [grados|°c]"
    final tempMatch = RegExp(
      r'temperatura\s*(?:de\s*)?(\d+(?:[.,]\d+)?)\s*(?:grados?|°c|celsius)?',
    ).firstMatch(text);
    if (tempMatch != null) {
      final value = _parseNumber(tempMatch.group(1));
      if (value != null && value >= 30 && value <= 45) {
        return value;
      }
    }

    // "temp [de] X"
    final tempShortMatch = RegExp(
      r'\btemp\.?\s*(?:de\s*)?(\d+(?:[.,]\d+)?)\s*(?:grados?|°c|celsius)?',
    ).firstMatch(text);
    if (tempShortMatch != null) {
      final value = _parseNumber(tempShortMatch.group(1));
      if (value != null && value >= 30 && value <= 45) {
        return value;
      }
    }

    // "X grados [centigrados|celsius]" - only if in valid temp range
    final gradosMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*grados?\s*(?:centigrados?|celsius)?',
    ).firstMatch(text);
    if (gradosMatch != null) {
      final value = _parseNumber(gradosMatch.group(1));
      if (value != null && value >= 30 && value <= 45) {
        return value;
      }
    }

    return null;
  }

  /// Parses oxygen saturation (SpO2).
  /// Patterns: "SpO2 98", "saturacion 98", "sat 98%"
  static int? _parseSpo2(String text) {
    // "spo2 X" or "sp02 X" (common typo with zero)
    final spo2Match = RegExp(
      r'sp[o0]2\s*(?:de\s*)?(\d+)\s*%?',
    ).firstMatch(text);
    if (spo2Match != null) {
      final value = int.tryParse(spo2Match.group(1) ?? '');
      if (value != null && value >= 50 && value <= 100) {
        return value;
      }
    }

    // "saturacion [de oxigeno] [de] X"
    final satMatch = RegExp(
      r'saturacion\s*(?:de\s*oxigeno\s*)?(?:de\s*)?(\d+)\s*%?',
    ).firstMatch(text);
    if (satMatch != null) {
      final value = int.tryParse(satMatch.group(1) ?? '');
      if (value != null && value >= 50 && value <= 100) {
        return value;
      }
    }

    // "sat X%" or "sat. X"
    final satShortMatch = RegExp(
      r'\bsat\.?\s*(?:de\s*)?(\d+)\s*%',
    ).firstMatch(text);
    if (satShortMatch != null) {
      final value = int.tryParse(satShortMatch.group(1) ?? '');
      if (value != null && value >= 50 && value <= 100) {
        return value;
      }
    }

    // "oximetria X" or "oximetria de X"
    final oxiMatch = RegExp(
      r'oximetria\s*(?:de\s*)?(\d+)\s*%?',
    ).firstMatch(text);
    if (oxiMatch != null) {
      final value = int.tryParse(oxiMatch.group(1) ?? '');
      if (value != null && value >= 50 && value <= 100) {
        return value;
      }
    }

    return null;
  }

  /// Parses prognosis.
  /// Patterns: "pronostico bueno", "pronostico reservado", "pronostico malo"
  static String? _parsePrognosis(String text) {
    // "pronostico [para la vida/funcion] X"
    final progMatch = RegExp(
      r'pronostico\s*(?:para\s*la\s*(?:vida|funcion)\s*)?'
      r'(bueno|favorable|reservado|malo|grave|critico|incierto)',
    ).firstMatch(text);
    if (progMatch != null) {
      return _capitalizePrognosis(progMatch.group(1));
    }

    // Also check for full phrases
    if (text.contains('buen pronostico')) {
      return 'Bueno';
    }
    if (text.contains('pronostico favorable')) {
      return 'Favorable';
    }
    if (text.contains('mal pronostico')) {
      return 'Malo';
    }

    return null;
  }

  static String? _capitalizePrognosis(String? value) {
    if (value == null) return null;
    if (value.isEmpty) return null;
    return value[0].toUpperCase() + value.substring(1);
  }

  /// Parses a number string, handling both . and , as decimal separator.
  static double? _parseNumber(String? value) {
    if (value == null) return null;
    final normalized = value.replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}
