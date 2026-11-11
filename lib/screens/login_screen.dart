import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../core/api.dart';
import '../core/storage.dart';
import '../state/auth_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _login = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _busy = false;
  bool _show = false;
  Map<String, String> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    TokenStore.lastLogin().then((v) {
      if (v != null && mounted && _login.text.isEmpty) setState(() => _login.text = v);
    });
  }

  @override
  void dispose() {
    _login.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _fieldErrors = {};
    });
    try {
      await context.read<AuthState>().login(_login.text, _password.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'DEVICE_APPROVAL_REQUIRED') {
        await _info('Waiting for HR approval',
            '${e.message}\n\nHR approves it in the SkirlField web app under Approval Centre → Phone changes. Then sign in here again.');
      } else if (e.code == 'VALIDATION_FAILED') {
        setState(() => _fieldErrors = e.fields);
      } else {
        showError(context, e);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _info(String title, String text) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );

  Future<void> _forgot() async {
    final ctrl = TextEditingController(text: _login.text);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('We will email a reset link if this login has an email address. Otherwise ask HR to reset your password.'),
          const SizedBox(height: 14),
          TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Email or phone'), keyboardType: TextInputType.emailAddress),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), style: FilledButton.styleFrom(minimumSize: const Size(100, 44)), child: const Text('Send')),
        ],
      ),
    );
    if (ok != true || ctrl.text.trim().isEmpty || !mounted) return;
    try {
      await context.read<AuthState>().forgotPassword(ctrl.text);
      if (mounted) showSnack(context, 'If that login exists, a reset link is on its way.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = context.watch<AuthState>().message;
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14)),
                      child: const Icon(Icons.my_location, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(Config.appName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.navy)),
                      Text('FIELD OPS SUITE', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: AppColors.muted, fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                  const SizedBox(height: 36),
                  const Text('Sign in', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.navy)),
                  const SizedBox(height: 6),
                  const Text('Use the login HR gave you. Your first sign-in registers this phone for duty.', style: TextStyle(color: AppColors.muted, height: 1.35)),
                  const SizedBox(height: 24),
                  if (msg != null) ...[
                    Banner2(text: msg, icon: Icons.lock_clock_outlined),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _login,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.username, AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: 'Email or phone', prefixIcon: const Icon(Icons.person_outline), errorText: _fieldErrors['login']),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your email or phone' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: !_show,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: _fieldErrors['password'],
                      suffixIcon: IconButton(
                        tooltip: _show ? 'Hide password' : 'Show password',
                        icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                        onPressed: () => setState(() => _show = !_show),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : const Text('Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(onPressed: _busy ? null : _forgot, child: const Text('Forgot password?')),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
