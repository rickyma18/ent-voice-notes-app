import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ai_engine.dart';
import '../../domain/sources/engine_setting_source.dart';

/// SharedPreferences implementation of [EngineSettingSource].
///
/// Persists the selected AI engine using the enum's storage key.
class EngineSettingSourceImpl implements EngineSettingSource {
  EngineSettingSourceImpl(this._prefs);

  final SharedPreferences _prefs;
  static const String _prefsKey = 'selected_ai_engine';

  @override
  Future<AiEngine> getEngine() async {
    final String? storedKey = _prefs.getString(_prefsKey);
    return AiEngine.fromString(storedKey);
  }

  @override
  Future<void> setEngine(AiEngine engine) async {
    await _prefs.setString(_prefsKey, engine.storageKey);
  }
}
