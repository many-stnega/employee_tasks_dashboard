import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sms_sender/sms_sender.dart';

/// Abstraction so tests can run without the SMS plugin.
abstract class SmsGateway {
  Future<void> send({required String phone, required String body});
}

class DeviceSmsGateway implements SmsGateway {
  @override
  Future<void> send({required String phone, required String body}) async {
    final sms = await Permission.sms.request();
    if (!sms.isGranted) {
      throw StateError('SMS permission was not granted.');
    }
    // The sms_sender plugin reads active subscriptions to pick a SIM slot.
    // Without READ_PHONE_STATE it sees an empty list and reports NO_SIM even
    // when a SIM is inserted.
    final phoneState = await Permission.phone.request();
    if (!phoneState.isGranted) {
      throw StateError(
        'Phone state permission was not granted; the app cannot read the SIM slot.',
      );
    }
    int simSlot = 0;
    try {
      final cards = await SmsSender.getSimCards();
      if (cards.isEmpty) {
        throw StateError('No active SIM card found. Insert or enable a SIM first.');
      }
      simSlot = cards.first.simSlot;
    } on PlatformException catch (error) {
      throw StateError(_friendlyError(error));
    }
    try {
      await SmsSender.sendSms(
        phoneNumber: phone.trim(),
        message: body.trim(),
        simSlot: simSlot,
      );
    } on PlatformException catch (error) {
      throw StateError(_friendlyError(error));
    }
  }

  String _friendlyError(PlatformException error) => switch (error.code) {
        'NO_SIM' =>
          'No active SIM card found. Insert or enable a SIM, then try again.',
        'INVALID_SIM_SLOT' =>
          'The selected SIM slot is not available on this device.',
        'PERMISSION_DENIED' =>
          'Android denied SMS sending permission.',
        'ACTIVITY_NULL' =>
          'SMS cannot be sent from a background job without an active screen.',
        _ => error.message ?? 'SMS sending failed.',
      };
}
