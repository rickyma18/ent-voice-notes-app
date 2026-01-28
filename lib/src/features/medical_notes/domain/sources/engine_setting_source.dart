import '../entities/ai_engine.dart';

/// Abstract source for persisting and retrieving the selected AI engine.
///
/// Implementations handle the actual storage mechanism (e.g., SharedPreferences).
abstract class EngineSettingSource {
  /// Retrieves the currently selected AI engine.
  ///
  /// Returns [AiEngine.openai] if no engine has been persisted yet.
  Future<AiEngine> getEngine();

  /// Persists the selected AI engine.
  ///
  /// [engine] - The engine to save as the default.
  Future<void> setEngine(AiEngine engine);
}
