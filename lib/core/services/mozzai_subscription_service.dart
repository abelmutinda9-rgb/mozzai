import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class MozzaiSubscription {
  final String deviceId;
  final String status;
  final String planName;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool isPremium;
  final int daysRemaining;

  const MozzaiSubscription({
    required this.deviceId,
    required this.status,
    required this.planName,
    this.startsAt,
    this.expiresAt,
    required this.isPremium,
    required this.daysRemaining,
  });

  factory MozzaiSubscription.empty(String deviceId) {
    return MozzaiSubscription(
      deviceId: deviceId,
      status: 'none',
      planName: 'MOZZAI Premium',
      isPremium: false,
      daysRemaining: 0,
    );
  }

  factory MozzaiSubscription.fromJson(Map<String, dynamic> json) {
    return MozzaiSubscription(
      deviceId: json['device_id'] as String? ?? '',
      status: json['status'] as String? ?? 'none',
      planName: json['plan_name'] as String? ?? 'MOZZAI Premium',
      startsAt: json['starts_at'] != null ? DateTime.tryParse(json['starts_at']) : null,
      expiresAt: json['expires_at'] != null ? DateTime.tryParse(json['expires_at']) : null,
      isPremium: json['is_premium'] == true,
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
    );
  }
}

class MozzaiSubscriptionService {
  MozzaiSubscriptionService._();
  static final MozzaiSubscriptionService instance = MozzaiSubscriptionService._();

  static const String baseUrl = 'https://mozzai-premium-control-center.lovable.app';
  static const String _storageKeyDeviceId = 'mozzai_persistent_device_id_v1';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final ValueNotifier<MozzaiSubscription?> subscriptionNotifier = ValueNotifier<MozzaiSubscription?>(null);

  String? _cachedDeviceId;

  String? get currentDeviceId => _cachedDeviceId;
  bool get isPremium => subscriptionNotifier.value?.isPremium == true;

  /// Generate or retrieve a random installation identity stored in secure storage.
  /// This is not Android hardware attestation: a reinstall may require support/re-purchase.
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }

    try {
      final storedId = await _secureStorage.read(key: _storageKeyDeviceId);
      if (storedId != null && storedId.isNotEmpty) {
        _cachedDeviceId = storedId;
        return storedId;
      }

      String deviceId;
      if (Platform.isAndroid) {
        try {
          final androidInfo = await DeviceInfoPlugin().androidInfo;
          // Deterministic Android hardware identity: survives app reinstallation and data clears
          final seed = [
            'mozzai_android_v2',
            androidInfo.brand,
            androidInfo.model,
            androidInfo.device,
            androidInfo.board,
            androidInfo.hardware,
            androidInfo.fingerprint,
            androidInfo.id,
          ].join(':');
          deviceId = 'mozzai_' + sha256.convert(utf8.encode(seed)).toString();
        } catch (_) {
          final random = Random.secure();
          final bytes = List<int>.generate(32, (_) => random.nextInt(256));
          deviceId = 'mozzai_' + sha256.convert(bytes).toString();
        }
      } else {
        final random = Random.secure();
        final bytes = List<int>.generate(32, (_) => random.nextInt(256));
        deviceId = 'mozzai_' + sha256.convert(bytes).toString();
      }

      await _secureStorage.write(key: _storageKeyDeviceId, value: deviceId);
      _cachedDeviceId = deviceId;
      return deviceId;
    } catch (e) {
      debugPrint('[MOZZAI] Secure device identity unavailable: $e');
      rethrow;
    }
  }

  /// Register device and sync subscription status with MOZZAI backend
  Future<MozzaiSubscription> initAndVerify() async {
    String devId;
    try {
      devId = await getDeviceId();
    } catch (_) {
      final unavailable = MozzaiSubscription.empty('');
      subscriptionNotifier.value = unavailable;
      return unavailable;
    }

    String model = '';
    String osVersion = '';
    String appVersion = '';

    try {
      final pkg = await PackageInfo.fromPlatform();
      appVersion = pkg.version;
    } catch (_) {}

    try {
      if (Platform.isAndroid) {
        final android = await DeviceInfoPlugin().androidInfo;
        model = android.brand + ' ' + android.model;
        osVersion = 'Android ' + android.version.release + ' (SDK ' + android.version.sdkInt.toString() + ')';
      }
    } catch (_) {}

    try {
      final regUrl = Uri.parse(baseUrl + '/api/public/devices/register-device');
      final regRes = await http
          .post(
            regUrl,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': devId,
              'model': model.isNotEmpty ? model : null,
              'os_version': osVersion.isNotEmpty ? osVersion : null,
              'app_version': appVersion.isNotEmpty ? appVersion : null,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (regRes.statusCode == 200) {
        final data = jsonDecode(regRes.body);
        if (data['ok'] == true && data['subscription'] != null) {
          final sub = MozzaiSubscription.fromJson(data['subscription'] as Map<String, dynamic>);
          subscriptionNotifier.value = sub;
          return sub;
        }
      }
    } catch (e) {
      debugPrint('[MOZZAI] Device register error: $e');
    }

    return verifySubscription();
  }

  /// Verify subscription status from backend
  Future<MozzaiSubscription> verifySubscription() async {
    String devId;
    try {
      devId = await getDeviceId();
    } catch (_) {
      final unavailable = MozzaiSubscription.empty('');
      subscriptionNotifier.value = unavailable;
      return unavailable;
    }
    try {
      final url = Uri.parse(baseUrl + '/api/public/devices/verify-subscription?device_id=' + devId);
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['ok'] == true && data['subscription'] != null) {
          final sub = MozzaiSubscription.fromJson(data['subscription'] as Map<String, dynamic>);
          subscriptionNotifier.value = sub;
          return sub;
        }
      }
    } catch (e) {
      debugPrint('[MOZZAI] Verify subscription error: $e');
    }

    // Fail closed: network errors must not preserve a stale Premium grant.
    final unavailable = MozzaiSubscription.empty(devId);
    subscriptionNotifier.value = unavailable;
    return unavailable;
  }

  /// Initiate PayHero M-Pesa STK Push
  Future<Map<String, dynamic>> initiateMpesaPayment(String phoneNumber) async {
    final devId = await getDeviceId();
    try {
      final url = Uri.parse(baseUrl + '/api/public/payments/stk-push');
      final res = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'device_id': devId,
              'phone_number': phoneNumber.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    } catch (e) {
      return {
        'ok': false,
        'error': 'Connection to MOZZAI payment server failed: ' + e.toString(),
      };
    }
  }

  /// Poll for subscription activation following STK push
  Future<bool> pollForActivation({
    Duration timeout = const Duration(seconds: 60),
    Duration interval = const Duration(seconds: 3),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(interval);
      final sub = await verifySubscription();
      if (sub.isPremium) {
        return true;
      }
    }
    return false;
  }
}
