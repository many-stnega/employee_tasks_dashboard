import 'package:permission_handler/permission_handler.dart';
import 'package:sms_sender/sms_sender.dart';

/// Abstraction so tests can run without the SMS plugin.
abstract class SmsGateway {
  Future<void> send({required String phone, required String body});
}

class DeviceSmsGateway implements SmsGateway {
  @override
  Future<void> send({required String phone, required String body}) async {
    final status = await Permission.sms.request();
    if (!status.isGranted) {
      throw StateError('SMS permission was not granted.');
    }
    await SmsSender.sendSms(phoneNumber: phone.trim(), message: body.trim());
  }
}
