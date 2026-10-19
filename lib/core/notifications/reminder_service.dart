import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../models/stage8_models.dart';

/// Telefonning o'z bildirishnomalari: maqsad muddati kelganda eslatma va yangi bildirishnomalar.
/// Eslatmalar tizim tomonidan rejalashtiriladi (ilova yopiq bo'lsa ham ishlaydi); vaqt bir necha daqiqaga kechikishi mumkin.
class ReminderService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails('hosilx_main', 'Hosil X', channelDescription: 'Maqsad eslatmalari va yangiliklar',
        importance: Importance.high, priority: Priority.high),
  );

  static Future<void> init() async {
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Tashkent'));
      await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
      _ready = true;
    } catch (_) {
      _ready = false; // bildirishnomalar ishlamasa ham ilova ochilaveradi
    }
  }

  /// Faqat kelajakdagi, bajarilmagan maqsadlar uchun eslatma rejalashtiradi (eskilari bekor qilinadi).
  static Future<void> sync(List<Goal> goals) async {
    if (!_ready) return;
    try {
      for (final r in await _plugin.pendingNotificationRequests()) {
        await _plugin.cancel(r.id);
      }
      final now = DateTime.now();
      var n = 0;
      for (final g in goals) {
        if (g.done || !g.dueAt.isAfter(now) || n >= 50) continue;
        await _plugin.zonedSchedule(g.id.hashCode & 0x7fffffff, '⏰ ${g.title}', g.description, tz.TZDateTime.from(g.dueAt, tz.local), _details,
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime);
        n++;
      }
    } catch (_) {}
  }

  static Future<void> show(String title, String? body) async {
    if (!_ready) return;
    try {
      await _plugin.show(DateTime.now().millisecondsSinceEpoch & 0x7fffffff, title, body, _details);
    } catch (_) {}
  }
}
