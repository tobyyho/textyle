import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountPasswordPage extends StatefulWidget {
  const AccountPasswordPage({super.key, this.onSaved});
  final VoidCallback? onSaved;
  @override
  State<AccountPasswordPage> createState() => _AccountPasswordPageState();
}
class _AccountPasswordPageState extends State<AccountPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;
  bool _busy = false;
  @override
  void dispose() { _password.dispose(); _confirm.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_password.text.length < 8 || _password.text != _confirm.text) {
      setState(() => _error = 'Use at least 8 characters and enter the same password twice.'); return;
    }
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _password.text));
      if (!mounted) return;
      if (widget.onSaved != null) { widget.onSaved!(); } else { Navigator.pop(context); }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update your password. Try again.');
    } finally { if (mounted) setState(() => _busy = false); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF4F7FA), appBar: AppBar(title: const Text('Set password')),
    body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480),
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('Choose a new password', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
        const SizedBox(height: 24),
        TextField(controller: _password, obscureText: true, autocorrect: false, enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'New password')),
        const SizedBox(height: 16),
        TextField(controller: _confirm, obscureText: true, autocorrect: false, enableSuggestions: false,
          decoration: const InputDecoration(labelText: 'Confirm password')),
        const SizedBox(height: 24),
        if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save password')),
      ]))),
  );
}
