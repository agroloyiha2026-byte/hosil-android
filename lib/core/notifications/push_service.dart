import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../config/firebase_config.dart';
import 'reminder_service.dart';
import '../services/supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebasePushBackgroundHandler(RemoteMessage message) async {
  final options = FirebaseConfig.androidOptions;
  if (options == null) return;
  await Firebase.initializeApp(options: options);
}

class PushService {
  PushService._();

  static final Set<String> _shownIds = <String>{};
  static final Set<String> _shownNotificationIds = <String>{};
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;
  static bool initialized = false;

  static Future<bool> initialize() async {
    if (initialized) return true;
    final options = FirebaseConfig.androidOptions;
    if (options == null) return false;
    try {
      await Firebase.initializeApp(options: options);
      FirebaseMessaging.onBackgroundMessage(firebasePushBackgroundHandler);
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_showForeground);
      initialized = true;
      return true;
    } catch (error, stackTrace) {
      debugPrint('FCM initialization failed: $error\n$stackTrace');
      return false;
    }
  }

  static Future<void> requestPermission() async {
    if (!initialized) return;
    final result = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (result.authorizationStatus == AuthorizationStatus.denied) {
      throw StateError('Push notification permission was denied');
    }
  }

  static Future<String?> token() async {
    if (!initialized) return null;
    await requestPermission();
    return FirebaseMessaging.instance.getToken();
  }

  static Future<void> unregisterCurrentToken() async {
    if (!initialized || !SupabaseService.ready || SupabaseService.client.auth.currentUser == null) return;
    final currentToken = await FirebaseMessaging.instance.getToken();
    if (currentToken == null) return;
    await SupabaseService.client.rpc('unregister_device_token', params: {'p_token': currentToken});
  }

  static Stream<String> get tokenRefreshes =>
      initialized ? FirebaseMessaging.instance.onTokenRefresh : const Stream<String>.empty();

  static Stream<RemoteMessage> get openedMessages =>
      initialized ? FirebaseMessaging.onMessageOpenedApp : const Stream<RemoteMessage>.empty();

  static Future<RemoteMessage?> initialMessage() =>
      initialized ? FirebaseMessaging.instance.getInitialMessage() : Future.value(null);

  static bool claimNotification(String? notificationId) {
    if (notificationId == null || notificationId.isEmpty) return true;
    if (!_shownNotificationIds.add(notificationId)) return false;
    if (_shownNotificationIds.length > 500) {
      _shownNotificationIds.remove(_shownNotificationIds.first);
    }
    return true;
  }

  static Future<void> _showForeground(RemoteMessage message) async {
    if (!claimNotification(message.data['notification_id']?.toString())) return;
    final id = message.messageId;
    if (id != null && !_shownIds.add(id)) return;
    if (_shownIds.length > 200) _shownIds.remove(_shownIds.first);
    final title = message.notification?.title ?? message.data['title']?.toString();
    final body = message.notification?.body ?? message.data['body']?.toString();
    if (title == null || title.isEmpty) return;
    await ReminderService.show(title, body);
  }

  static Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
  }
}
