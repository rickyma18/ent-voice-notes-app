import 'package:flutter/material.dart';

import '../utility/validation/validation.dart';

extension ValidatorContextExtension on BuildContext {
  Validator get validator => Validator(this);
}
