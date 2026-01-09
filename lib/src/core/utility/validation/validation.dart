import 'package:flutter/material.dart';

// Core validation classes
export 'validation_impl.dart';

// Validation rules
export 'required_validation.dart';
export 'length_validation.dart';
export 'email_validation.dart';
export 'password_validation.dart';
export 'name_validation.dart';
export 'age_validation.dart';
export 'phone_validation.dart';

// Input rules and formatters
export 'input_rules.dart';
export 'input_formatters.dart';

abstract class Validation<T> {
  const Validation();

  String? validate(BuildContext context, T? value);
}
