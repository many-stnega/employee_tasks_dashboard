import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:material_ui/material_ui.dart';

import '../contact_repository.dart';

class ContactsPage extends StatefulWidget {
  final ContactRepository repository;

  const ContactsPage({super.key, required this.repository});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  List<Contact> _contacts = <Contact>[];
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final granted = await widget.repository.requestPermission();
      if (!granted) {
        _error = 'Contacts permission was not granted.';
        _contacts = <Contact>[];
      } else {
        _error = null;
        _contacts = await widget.repository.list();
      }
    } catch (error) {
      _error = 'Could not load contacts: $error';
    }
    if (mounted) setState(() => _loading = false);
  }

  static String _phone(Contact contact) =>
      contact.phones.isEmpty ? '' : contact.phones.first.number;

  Future<void> _editor(Contact? contact) async {
    final nameController =
        TextEditingController(text: contact?.displayName ?? '');
    final phoneController =
        TextEditingController(text: contact == null ? '' : _phone(contact));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(contact == null ? 'Add contact' : 'Edit contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    try {
      if (contact == null) {
        await widget.repository.create(
          name: nameController.text,
          phone: phoneController.text,
        );
      } else {
        await widget.repository.update(
          contact,
          name: nameController.text,
          phone: phoneController.text,
        );
      }
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $error')),
        );
      }
    }
  }

  Future<void> _delete(Contact contact) async {
    final id = contact.id;
    if (id == null) return;
    await widget.repository.delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filtered = _contacts.where((contact) {
      final text = '${contact.displayName ?? ''} ${_phone(contact)}'
          .toLowerCase();
      return text.contains(_query.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add contact',
        onPressed: () => _editor(null),
        child: const Icon(Icons.person_add_alt),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Search contacts',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(_error!,
                  style: TextStyle(color: scheme.error, fontSize: 13)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No contacts found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final contact = filtered[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(
                                (contact.displayName ?? '').isEmpty
                                    ? '?'
                                    : contact.displayName![0].toUpperCase(),
                              ),
                            ),
                            title: Text(contact.displayName ?? 'Unnamed'),
                            subtitle: Text(_phone(contact)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit contact',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _editor(contact),
                                ),
                                IconButton(
                                  tooltip: 'Delete contact',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(contact),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
