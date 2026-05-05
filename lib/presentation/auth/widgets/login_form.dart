import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../common/widgets/admin_layout/admin_spacing.dart';

class LoginForm extends StatefulWidget {
  const LoginForm({
    super.key,
    required this.loading,
    required this.onSubmit,
    this.errorText,
  });

  final bool loading;
  final String? errorText;
  final Future<void> Function(String credential, String password) onSubmit;

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _credentialController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late AnimationController _errorAnim;
  late Animation<double> _errorFade;
  late Animation<Offset> _errorSlide;

  @override
  void initState() {
    super.initState();
    _errorAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _errorFade = CurvedAnimation(parent: _errorAnim, curve: Curves.easeOut);
    _errorSlide = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _errorAnim, curve: Curves.easeOutCubic));
  }

  @override
  void didUpdateWidget(LoginForm old) {
    super.didUpdateWidget(old);
    if (widget.errorText != null && old.errorText == null) {
      _errorAnim.forward(from: 0);
    } else if (widget.errorText == null) {
      _errorAnim.reverse();
    }
  }

  @override
  void dispose() {
    _credentialController.dispose();
    _passwordController.dispose();
    _errorAnim.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Icon(icon, size: 20, color: AdminColors.textSecondary),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 52),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AdminColors.canvas.withValues(alpha: 0.7),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      labelStyle: TextStyle(
        color: AdminColors.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(
        color: AdminColors.textSecondary.withValues(alpha: 0.5),
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AdminColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AdminColors.border.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AdminColors.primaryAction,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7),
          width: 1,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: Theme.of(context).colorScheme.error,
          width: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Credential field ───────────────────────────────────────
            TextFormField(
              controller: _credentialController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [
                AutofillHints.email,
                AutofillHints.username,
              ],
              style: TextStyle(
                fontSize: 15,
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: _fieldDecoration(
                label: 'Email or phone',
                hint: 'you@school.org',
                icon: Icons.person_outline_rounded,
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            // ── Password field ─────────────────────────────────────────
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.password],
              style: TextStyle(
                fontSize: 15,
                color: AdminColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: _fieldDecoration(
                label: 'Password',
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                    color: AdminColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  splashRadius: 20,
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
            ),

            // ── Animated error banner ──────────────────────────────────
            if (widget.errorText != null)
              FadeTransition(
                opacity: _errorFade,
                child: SlideTransition(
                  position: _errorSlide,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer
                            .withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.error
                              .withValues(alpha: 0.25),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              widget.errorText!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: AdminSpacing.md),

            // ── Sign-in button (gradient) ──────────────────────────────
            _GradientSignInButton(
              loading: widget.loading,
              onPressed: _submit,
            ),

            const SizedBox(height: AdminSpacing.sm),

            // ── Footer hint ────────────────────────────────────────────
            Text(
              'Protected by school-level security',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AdminColors.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(
      _credentialController.text.trim(),
      _passwordController.text,
    );
  }
}

class _GradientSignInButton extends StatefulWidget {
  const _GradientSignInButton({
    required this.loading,
    required this.onPressed,
  });

  final bool loading;
  final VoidCallback onPressed;

  @override
  State<_GradientSignInButton> createState() => _GradientSignInButtonState();
}

class _GradientSignInButtonState extends State<_GradientSignInButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabled = widget.loading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapUp: disabled ? null : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _pressed ? 0.975 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: disabled ? 0.68 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AdminColors.primaryAction,
                  Color.lerp(
                    AdminColors.primaryAction,
                    const Color(0xFF3730A3),
                    0.45,
                  )!,
                ],
              ),
              boxShadow: _pressed || disabled
                  ? []
                  : [
                      BoxShadow(
                        color: AdminColors.primaryAction.withValues(alpha: 0.35),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: -4,
                      ),
                    ],
            ),
            alignment: Alignment.center,
            child: widget.loading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Sign in',
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}