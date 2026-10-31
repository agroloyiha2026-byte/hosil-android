import 'package:flutter/material.dart';
import '../../app/localization/l10n.dart';
import '../../core/services/supabase_service.dart';
import '../../core/widgets/widgets.dart';

/// AI credentials live only in the Supabase Edge Function environment.
class AssistantScreen extends StatefulWidget {
  final String mode;
  const AssistantScreen({super.key, this.mode = 'assistant'});
  @override
  State<AssistantScreen> createState() => _S();
}

class _S extends State<AssistantScreen> {
  final _q = TextEditingController();
  final _msgs = <Map<String, String>>[];
  bool _busy = false;
  late String _mode = widget.mode;

  bool get _configured => SupabaseService.ready;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _q.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _msgs.add({'role': 'user', 'content': text});
      _q.clear();
      _busy = true;
    });
    // context await'dan oldin ishlatiladi (async oraliqda BuildContext ishlatmaslik uchun)
    final msgLimit = context.tr('ai_limit');
    final msgGeneric = context.tr('error_generic');
    final msgNetwork = context.tr('error_network');
    final msgAuth = context.tr('error_auth');
    String answer;
    try {
      if (SupabaseService.client.auth.currentSession == null)
        throw StateError('Authenticated session is unavailable');
      final messages = [
        for (final message in _msgs) Map<String, String>.from(message)
      ];
      final res = await SupabaseService.client.functions.invoke(
        'ai-assistant',
        body: {
          'mode': _mode,
          'messages': messages.length > 12
              ? messages.sublist(messages.length - 12)
              : messages
        },
      );
      if (res.status == 200 && res.data is Map) {
        answer = (res.data['text'] as String?) ?? msgGeneric;
      } else {
        answer = res.status == 429 ? msgLimit : msgGeneric;
      }
    } on StateError {
      answer = msgAuth;
    } catch (error) {
      final diagnostic = error.toString();
      if (diagnostic.contains('429')) {
        answer = msgLimit;
      } else if (diagnostic.contains('401')) {
        answer = msgAuth;
      } else if (diagnostic.contains('SocketException') ||
          diagnostic.contains('ClientException')) {
        answer = msgNetwork;
      } else {
        answer = msgGeneric;
      }
    }
    if (mounted)
      setState(() {
        _msgs.add({'role': 'assistant', 'content': answer});
        _busy = false;
      });
  }

  @override
  Widget build(BuildContext context) {
    final s = Theme.of(context).colorScheme;
    if (!_configured) {
      return Scaffold(
          appBar: AppBar(title: Text(_title(context))),
          body: EmptyView(
              message: context.tr('assistant_unconfigured'),
              icon: Icons.settings_suggest_outlined));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_title(context)),
        actions: [
          PopupMenuButton<String>(
            tooltip: context.tr('ai_choose_mode'),
            initialValue: _mode,
            onSelected: (mode) => setState(() {
              _mode = mode;
              _msgs.clear();
            }),
            itemBuilder: (context) => [
              for (final mode in const [
                'doctor',
                'agro',
                'price',
                'finance',
                'calculator',
                'assistant'
              ])
                PopupMenuItem(
                    value: mode, child: Text(context.tr('ai_mode_$mode'))),
            ],
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(context.tr('assistant_note'),
                style: Theme.of(context).textTheme.bodySmall)),
        Expanded(
          child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final m in _msgs)
                  Align(
                    alignment: m['role'] == 'user'
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82),
                      decoration: BoxDecoration(
                          color: m['role'] == 'user'
                              ? s.primaryContainer
                              : s.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: s.onSurface.withValues(alpha: 0.08))),
                      child: SelectableText(m['content']!),
                    ),
                  ),
                if (_busy)
                  const Padding(
                      padding: EdgeInsets.all(8),
                      child: Center(child: CircularProgressIndicator())),
              ]),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(
                  child: TextField(
                      controller: _q,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                          hintText: context.tr('ask_hint'),
                          filled: true,
                          fillColor: s.surface,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14))))),
              const SizedBox(width: 8),
              IconButton.filled(
                  onPressed: _busy ? null : _send,
                  icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }

  String _title(BuildContext context) => context.tr('ai_mode_$_mode');
}
