import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/notifications/push_service.dart';
import '../../core/services/supabase_service.dart';
import '../auth/session_controller.dart';
import '../../app/router.dart';

final pushRegistrationBridgeProvider = Provider<void>((ref) {
  if (!PushService.initialized || !SupabaseService.ready) return;
  final router = ref.watch(routerProvider);
  Future<void> registerToken(String? token) async {
    final userId = ref.read(sessionProvider).user?.id;
    if (token == null || userId == null) return;
    try {
      await SupabaseService.client.rpc('register_device_token', params: {
        'p_token': token,
        'p_platform': 'android',
      });
    } catch (error, stackTrace) {
      debugPrint('FCM token registration failed: $error\n$stackTrace');
    }
  }

  Future<void> registerCurrentToken() async {
    if (ref.read(sessionProvider).user == null) return;
    try {
      await registerToken(await PushService.token());
    } catch (error, stackTrace) {
      debugPrint('FCM permission or token retrieval failed: $error\n$stackTrace');
    }
  }

  void openMessage(RemoteMessage message) {
    final data = message.data;
    final inquiryId = data['inquiry_id']?.toString();
    final productId = data['product_id']?.toString();
    final route = data['route']?.toString();
    final idPattern = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$', caseSensitive: false);
    if (inquiryId != null && idPattern.hasMatch(inquiryId)) {
      router.push('/chat/$inquiryId');
    } else if (productId != null && idPattern.hasMatch(productId)) {
      router.push('/product/$productId');
    } else if (route == '/notifications' || route == '/inquiries') {
      router.push(route!);
    } else if (route == '/profile') {
      router.push('/profile');
    }
  }

  final openedSubscription = PushService.openedMessages.listen(openMessage);
  final tokenSubscription = PushService.tokenRefreshes.listen((token) {
    unawaited(registerToken(token));
  }, onError: (Object error, StackTrace stackTrace) {
    debugPrint('FCM token refresh stream failed: $error\n$stackTrace');
  });

  unawaited(PushService.initialMessage().then((message) {
    if (message != null) openMessage(message);
  }).catchError((Object error, StackTrace stackTrace) {
    debugPrint('FCM initial message retrieval failed: $error\n$stackTrace');
  }));
  unawaited(registerCurrentToken());

  ref.listen(sessionProvider, (previous, next) {
    final newUser = next.user?.id;
    if (newUser != null && newUser != previous?.user?.id) {
      unawaited(registerCurrentToken());
    }
  });

  ref.onDispose(() {
    unawaited(openedSubscription.cancel());
    unawaited(tokenSubscription.cancel());
  });
});
