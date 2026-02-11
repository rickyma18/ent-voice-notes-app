import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'log.dart';

class RiverpodObserver extends ProviderObserver {
  /// Provider names whose values must never appear in logs.
  static const _sensitiveProviders = {
    'openAIApiKeyProvider',
  };

  bool _isSensitive(ProviderBase<Object?> provider) {
    final name = provider.name ?? provider.toString();
    return _sensitiveProviders.any((s) => name.contains(s));
  }

  String _safeValue(ProviderBase<Object?> provider, Object? value) {
    if (!_isSensitive(provider)) return '$value';
    if (value == null) return 'null';
    final s = value.toString();
    return 'len=${s.length}';
  }

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    Log.info(
      'Provider $provider was initialized with ${_safeValue(provider, value)}',
    );
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    Log.warning('Provider $provider was disposed');
  }

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (_isSensitive(provider)) {
      Log.info('Provider $provider updated (sensitive – value masked)');
    } else {
      Log.info('Provider $provider updated from $previousValue to $newValue');
    }
  }

  @override
  void providerDidFail(
    ProviderBase<Object?> provider,
    Object error,
    StackTrace stackTrace,
    ProviderContainer container,
  ) {
    Log.error('Provider $provider threw $error at $stackTrace');
  }
}
