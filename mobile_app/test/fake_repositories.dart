import 'package:employee_tasks_mobile/contact_repository.dart';
import 'package:employee_tasks_mobile/message_service.dart';
import 'package:employee_tasks_mobile/reminder_store.dart';
import 'package:employee_tasks_mobile/sms_job_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

class FakeContactRepository implements ContactRepository {
  final List<Contact> contacts = <Contact>[];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<List<Contact>> list() async => List<Contact>.from(contacts);

  @override
  Future<void> create({required String name, required String phone}) async {
    contacts.add(Contact(
      id: '${contacts.length + 1}',
      name: Name(first: name),
      phones: <Phone>[Phone(number: phone)],
    ));
  }

  @override
  Future<void> update(
    Contact contact, {
    required String name,
    required String phone,
  }) async {
    final index = contacts.indexWhere((item) => item.id == contact.id);
    if (index < 0) return;
    contacts[index] = Contact(
      id: contact.id,
      name: Name(first: name),
      phones: <Phone>[Phone(number: phone)],
    );
  }

  @override
  Future<void> delete(String id) async {
    contacts.removeWhere((contact) => contact.id == id);
  }
}

class FakeSmsGateway implements SmsGateway {
  final List<Map<String, String>> sent = <Map<String, String>>[];

  @override
  Future<void> send({required String phone, required String body}) async {
    sent.add(<String, String>{'phone': phone, 'body': body});
  }
}




class FakeSmsJobScheduler implements SmsJobScheduler {
  final List<int> scheduled = <int>[];
  final List<int> cancelled = <int>[];

  @override
  Future<void> schedule(Reminder reminder) async {
    scheduled.add(reminder.id);
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}
