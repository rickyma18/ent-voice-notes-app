import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../ui/docsoft_ui.dart';
import '../../../../../core/extensions/app_localization.dart';
import '../../../../../core/extensions/validation.dart';
import '../../../../../core/utility/validation/validation.dart';
import '../../../../core/router/route_names.dart';
import '../../../../features/authentication/login/riverpod/login_provider.dart';
import '../widgets/language_switcher.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _shouldRemember = ValueNotifier<bool>(false);

  // Auth sheet state
  bool _showSheet = false;
  bool _isLoginMode = true;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();

    ref.listenManual(loginProvider, (previous, next) {
      switch (next) {
        case AsyncData(:final value) when value != null:
          context.goNamed(RouteNames.home);
        case AsyncError(:final error):
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _shouldRemember.dispose();
    super.dispose();
  }

  void _openSheet({required bool loginMode}) {
    setState(() {
      _isLoginMode = loginMode;
      _showSheet = true;
    });
  }

  void _closeSheet() {
    setState(() {
      _showSheet = false;
    });
    // Clear form when closing
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
    });
    // Clear form when toggling mode
    _formKey.currentState?.reset();
    _emailController.clear();
    _passwordController.clear();
  }

  void _togglePasswordVisibility() {
    setState(() => _isPasswordVisible = !_isPasswordVisible);
  }

  void _onSubmit() {
    if (_formKey.currentState!.validate()) {
      if (_isLoginMode) {
        ref
            .read(loginProvider.notifier)
            .login(
              email: _emailController.text,
              password: _passwordController.text,
              shouldRemember: _shouldRemember.value,
            );
      } else {
        // Navigate to registration page for full registration flow
        _closeSheet();
        context.pushNamed(RouteNames.registration);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginProvider);

    return Scaffold(
      backgroundColor: DocsoftColors.background,
      body: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Base screen content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DocsoftSpacing.screenPadding,
              ),
              child: Column(
                children: [
                  // Language switcher
                  Align(
                    alignment: Directionality.of(context) == TextDirection.ltr
                        ? Alignment.topRight
                        : Alignment.topLeft,
                    child: const LanguageSwitcherWidget(),
                  ),

                  const Spacer(flex: 2),

                  // Branding section
                  _buildBrandingSection(context),

                  const Spacer(flex: 3),

                  // Action buttons
                  _buildActionButtons(context),

                  const SizedBox(height: DocsoftSpacing.xl),
                ],
              ),
            ),
          ),

          // Dimmed overlay when sheet is visible
          if (_showSheet)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSheet,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showSheet ? 1.0 : 0.0,
                  child: ColoredBox(color: Colors.black.withValues(alpha: 0.3)),
                ),
              ),
            ),

          // Animated auth sheet
          DocsoftAuthSheet(
            visible: _showSheet,
            onClose: _closeSheet,
            onOpen: () => _openSheet(loginMode: true),
            title: _isLoginMode ? '¡Bienvenido de vuelta!' : 'Crear cuenta',
            heightPercentage: 0.70,
            child: Form(
              key: _formKey,
              child: _buildFormContent(context, state),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandingSection(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Docsoft symbol with gradient background
        Container(
          width: 120,
          height: 120,
          padding: const EdgeInsets.all(26), // un poco más de aire
          decoration: BoxDecoration(
            gradient: DocsoftColors.primaryGradient,
            borderRadius: BorderRadius.circular(28), // ligeramente más suave
            boxShadow: [
              BoxShadow(
                color: DocsoftColors.primary.withValues(alpha: 0.22),
                blurRadius: 32,
                spreadRadius: 2,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Image.asset(
            'assets/branding/symbol/docsoft_symbol.png',
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            color: Colors.white,
            colorBlendMode: BlendMode.srcIn,
          ),
        ),

        const SizedBox(height: DocsoftSpacing.lg),

        // App name
        Text(
          'Docsoft',
          style: DocsoftTextStyles.headline.copyWith(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: DocsoftSpacing.sm),

        // Tagline
        Text(
          context.locale.appTagline,
          style: DocsoftTextStyles.body.copyWith(
            color: DocsoftColors.textSecondary,
            fontSize: 16,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DocsoftPrimaryButton(
          onPressed: () => _openSheet(loginMode: true),
          label: context.locale.login,
          fullWidth: true,
        ),
        const SizedBox(height: DocsoftSpacing.md),
        DocsoftSecondaryButton(
          onPressed: () => _openSheet(loginMode: false),
          label: context.locale.signUp,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildFormContent(BuildContext context, AsyncValue state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Form fields
        DocsoftInput(
          controller: _emailController,
          label: context.locale.email,
          hint: 'ejemplo@correo.com',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          prefixIcon: const Icon(Icons.email_outlined, size: 20),
          validator: context.validator.apply([RequiredValidation()]),
        ),
        const SizedBox(height: DocsoftSpacing.md),

        DocsoftInput(
          controller: _passwordController,
          label: context.locale.password,
          hint: '••••••••',
          obscureText: !_isPasswordVisible,
          textInputAction: TextInputAction.done,
          prefixIcon: const Icon(Icons.lock_outline, size: 20),
          suffixIcon: GestureDetector(
            onTap: _togglePasswordVisibility,
            child: Icon(
              _isPasswordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
            ),
          ),
          validator: context.validator.apply([
            RequiredValidation(),
            PasswordValidation(minLength: 6),
          ]),
        ),

        // Remember me & Forgot password (only for login)
        if (_isLoginMode) ...[
          const SizedBox(height: DocsoftSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Remember me
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder(
                    valueListenable: _shouldRemember,
                    builder: (context, value, _) {
                      return SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: value,
                          onChanged: (v) => _shouldRemember.value = v ?? false,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: DocsoftSpacing.xs),
                  Text(
                    context.locale.rememberMe,
                    style: DocsoftTextStyles.caption,
                  ),
                ],
              ),
              // Forgot password
              GestureDetector(
                onTap: () {
                  _closeSheet();
                  context.pushNamed(RouteNames.resetPassword);
                },
                child: Text(
                  context.locale.forgotPassword,
                  style: DocsoftTextStyles.caption.copyWith(
                    color: DocsoftColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: DocsoftSpacing.lg),

        // Submit button
        DocsoftPrimaryButton(
          onPressed: state.isLoading ? null : _onSubmit,
          label: _isLoginMode
              ? context.locale.login
              : context.locale.continueAction,
          isLoading: state.isLoading,
          fullWidth: true,
        ),

        const SizedBox(height: DocsoftSpacing.lg),

        // Toggle mode link
        Center(
          child: GestureDetector(
            onTap: _toggleMode,
            child: RichText(
              text: TextSpan(
                style: DocsoftTextStyles.body.copyWith(
                  color: DocsoftColors.textSecondary,
                ),
                children: [
                  TextSpan(
                    text: _isLoginMode
                        ? context.locale.dontHaveAccount
                        : context.locale.alreadyHaveAccount,
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(
                    text: _isLoginMode
                        ? context.locale.signUp
                        : context.locale.signIn,
                    style: DocsoftTextStyles.body.copyWith(
                      color: DocsoftColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
