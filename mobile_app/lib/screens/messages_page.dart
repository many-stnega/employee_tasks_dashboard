import 'package:material_ui/material_ui.dart';

import '../format.dart';
import '../message_store.dart';

class MessagesPage extends StatefulWidget {
  final MessageStore store;

  const MessagesPage({super.key, required this.store});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _body = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _phone.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_phone.text.trim().isEmpty || _body.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a number and a message.')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await widget.store.send(_phone.text, _body.text);
      if (!mounted) return;
      _body.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not send: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        return Scaffold(
          appBar: AppBar(title: const Text('Messages')),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: TextField(
                  controller: _body,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
                    label: Text(_sending ? 'Sending…' : 'Send SMS'),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('SENT FROM THIS APP',
                        style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.7,
                            fontWeight: FontWeight.w700,
                            color: scheme.onSurfaceVariant)),
                    const Spacer(),
                    Text('${widget.store.messages.length}',
                        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: widget.store.messages.isEmpty
                    ? const Center(child: Text('No messages sent yet.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: widget.store.messages.length,
                        itemBuilder: (context, index) {
                          final message = widget.store.messages[index];
                          return Card(
                            child: ListTile(
                              title: Text(message.phone),
                              subtitle: Text(message.body),
                              trailing: Text(
                                dateTimeLabel(message.sentAt),
                                style: TextStyle(
                                    fontSize: 11, color: scheme.onSurfaceVariant),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
