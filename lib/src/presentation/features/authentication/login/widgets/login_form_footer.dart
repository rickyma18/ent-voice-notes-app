import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/extensions/app_localization.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/theme/theme.dart';

class LoginFormFooter extends ConsumerWidget {
  const LoginFormFooter({super.key, required this.shouldRemember});

  final ValueNotifier<bool> shouldRemember;

  void _toggleRememberMe(bool? value) {
    shouldRemember.value = value ?? false;
  }

  void _navigateToResetPassword(BuildContext context) {
    context.pushNamed(RouteNames.resetPassword);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: context.color.text.secondary,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Transform.translate(
            offset: const Offset(-10, 0),
            child: Row(
              children: [
                ValueListenableBuilder(
                  valueListenable: shouldRemember,
                  builder: (context, value, _) {
                    return Checkbox(value: value, onChanged: _toggleRememberMe);
                  },
                ),
                Text(context.locale.rememberMe),
              ],
            ),
          ),
          Transform.translate(
            offset: const Offset(10, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _navigateToResetPassword(context),
                child: Text(context.locale.forgotPassword),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
