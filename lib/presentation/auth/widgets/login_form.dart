import 'package:flutter/material.dart';

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

class _LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _credentialController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _credentialController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            TextFormField(
              controller: _credentialController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              decoration: const InputDecoration(
                labelText: 'Email or phone',
                hintText: 'you@school.org',
                prefixIcon: Icon(Icons.person_outline_rounded, size: 22),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: AdminSpacing.sm),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              autofillHints: const [AutofillHints.password],
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded, size: 22),
              ),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (widget.errorText != null) ...[
              const SizedBox(height: AdminSpacing.sm),
              Material(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.md,
                    vertical: AdminSpacing.sm,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: AdminSpacing.sm),
                      Expanded(
                        child: Text(
                          widget.errorText!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: AdminSpacing.md),
            FilledButton(
              onPressed: widget.loading ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: widget.loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.95,
                        ),
                      ),
                    )
                  : const Text('Sign in'),
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
