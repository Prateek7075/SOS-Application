import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/emergency_contact.dart';
import '../models/user_profile.dart';

class DirectSmsService {
  static const MethodChannel _channel = MethodChannel('sos_sms_channel');

  String createEmergencyMessage({required double latitude, required double longitude, UserProfile? profile, String? trackingUrl,})
  {

    final hasProfile = profile != null && profile.hasUsefulData;

    final profileText = hasProfile
        ? '''
Name: ${profile.name.isEmpty ? '-' : profile.name}
Phone: ${profile.phone.isEmpty ? '-' : profile.phone}
Blood Group: ${profile.bloodGroup.isEmpty ? '-' : profile.bloodGroup}
Emergency Relative: ${profile.relativeName.isEmpty ? '-' : profile.relativeName} - ${profile.relativePhone.isEmpty ? '-' : profile.relativePhone}
Address: ${profile.address.isEmpty ? '-' : profile.address}
''': '';

    final trackingText = trackingUrl != null && trackingUrl.trim().isNotEmpty
        ? '''
Live tracking link:
$trackingUrl
''': '';


    return '''
EMERGENCY SOS!
I need help.
            
$profileText $trackingText My current location:
https://maps.google.com/?q=$latitude,$longitude
            
Please contact me immediately.
''';


  }

  Future<bool> requestSmsPermission() async {
    final currentStatus = await Permission.sms.status;

    if (currentStatus.isGranted) {
      return true;
    }

    final newStatus = await Permission.sms.request();

    return newStatus.isGranted;
  }

  Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>(
        'sendSms',
        {
          'phoneNumber': phoneNumber,
          'message': message,
        },
      );

      return result == true;
    } catch (error) {
      return false;
    }
  }

Future<int> sendEmergencySmsToContacts({required List<EmergencyContact> contacts, required double latitude, required double longitude, UserProfile? profile, String? trackingUrl,})
async {
    final hasPermission = await requestSmsPermission();

    if (!hasPermission) {
      return 0;
    }

    final message = createEmergencyMessage(
      latitude: latitude,
      longitude: longitude,
      profile: profile,
      trackingUrl: trackingUrl,
    );

    int successCount = 0;

    for (final contact in contacts) {
      final sent = await sendSms(
        phoneNumber: contact.phone,
        message: message,
      );

      if (sent) {
        successCount++;
      }
    }

    return successCount;
  }
}