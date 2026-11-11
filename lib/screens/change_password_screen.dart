import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/api.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// forced = first sign-in with a temporary password (no way back except signing out).
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});
  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  Map<String, String> _errors = {};

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _errors = {};
    });
    try {
      await context.read<AuthState>().changePassword(_current.text, _next.text);
      if (!mounted) return;
      showSnack(context, 'Password changed.');
      if (!widget.forced) Navigator.pop(context);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'VALIDATION_FAILED') {
        setState(() => _errors = e.fields);
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Change password'),
        automaticallyImplyLeading: !widget.forced,
        actions: [
          if (widget.forced) TextButton(onPressed: () => context.read<AuthState>().logout(), child: const Text('Sign out')),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              if (widget.forced) ...[
                const Banner2(
                  text: 'You signed in with a temporary password. Choose your own password to continue.',
                  icon: Icons.key_outlined,
                  color: AppColors.primary,
                  soft: AppColors.primarySoft,
                ),
                const SizedBox(height: 20),
              ],
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: InputDecoration(labelText: widget.forced ? 'Temporary password' : 'Current password', errorText: _errors['current_password']),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _next,
                obscureText: true,
                decoration: InputDecoration(labelText: 'New password', helperText: 'At least 8 characters with letters and numbers', errorText: _errors['new_password']),
                validator: (v) => (v == null || v.length < 8) ? 'At least 8 characters' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Repeat new password'),
                validator: (v) => v != _next.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _busy ? null : _submit,
                child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Save password'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
