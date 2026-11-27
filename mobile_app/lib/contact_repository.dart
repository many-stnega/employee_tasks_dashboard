import 'package:flutter_contacts/flutter_contacts.dart';

abstract class ContactRepository {
  Future<bool> requestPermission();
  Future<List<Contact>> list();
  Future<void> create({required String name, required String phone});
  Future<void> update(
    Contact contact, {
    required String name,
    required String phone,
  });
  Future<void> delete(String id);
}

class NativeContactRepository implements ContactRepository {
  static Name _name(String raw) {
    final parts = raw.trim().split(RegExp(r'\s+'))..removeWhere((p) => p.isEmpty);
    if (parts.isEmpty) return Name(first: 'Unnamed');
    return Name(
      first: parts.first,
      last: parts.length > 1 ? parts.sublist(1).join(' ') : '',
    );
  }

  @override
  Future<bool> requestPermission() async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.readWrite);
    return status == PermissionStatus.granted;
  }

  @override
  Future<List<Contact>> list() => FlutterContacts.getAll(
        properties: <ContactProperty>{
          ContactProperty.name,
          ContactProperty.phone,
        },
      );

  @override
  Future<void> create({required String name, required String phone}) async {
    await FlutterContacts.create(Contact(
      name: _name(name),
      phones: <Phone>[Phone(number: phone.trim())],
    ));
  }

  @override
  Future<void> update(
    Contact contact, {
    required String name,
    required String phone,
  }) async {
    await FlutterContacts.update(contact.copyWith(
      name: _name(name),
      phones: <Phone>[Phone(number: phone.trim())],
    ));
  }

  @override
  Future<void> delete(String id) => FlutterContacts.delete(id);
}
