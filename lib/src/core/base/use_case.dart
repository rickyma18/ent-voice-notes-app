import 'failure.dart';
import 'result.dart';

/// Base class for all UseCases
///
/// T: return type
/// Params: input parameter type
abstract class UseCase<T, Params> {
  Future<Result<T, Failure>> call(Params params);
}

/// Use when a use case does not require parameters
class NoParams {
  const NoParams();
}
