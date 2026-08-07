import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import '../models/gamification.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );
  }

  // Request permissions
  static Future<bool> requestPermissions() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final iosPlugin = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }

    if (iosPlugin != null) {
      await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    return true;
  }

  // Schedule study reminder
  static Future<void> scheduleStudyReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'study_reminders',
      'Study Reminders',
      channelDescription: 'Notifications for study tasks and lessons',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Schedule daily reminder
  static Future<void> scheduleDailyReminder({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminders',
      'Daily Reminders',
      channelDescription: 'Daily learning reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    await _notifications.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Show immediate notification
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'instant_notifications',
      'Instant Notifications',
      channelDescription: 'Immediate notifications',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details);
  }

  // Streak reminder
  static Future<void> sendStreakReminder(int currentStreak) async {
    await showNotification(
      id: 1000,
      title: '🔥 Keep your streak alive!',
      body: 'You\'re on a $currentStreak-day streak. Learn something today to keep it going!',
    );
  }

  // Achievement unlocked
  static Future<void> notifyAchievementUnlocked(Achievement achievement) async {
    await showNotification(
      id: achievement.id.hashCode,
      title: '🏆 Achievement Unlocked!',
      body: '${achievement.title} - +${achievement.xpReward} XP',
    );
  }

  // Quiz completion
  static Future<void> notifyQuizCompleted(String quizTitle, int score) async {
    String emoji = score >= 90 ? '🎉' : score >= 70 ? '👏' : '📚';
    await showNotification(
      id: quizTitle.hashCode,
      title: '$emoji Quiz Completed!',
      body: '$quizTitle - Score: $score%',
    );
  }

  // Lesson reminder
  static Future<void> sendLessonReminder(String lessonTitle, DateTime when) async {
    await scheduleStudyReminder(
      id: lessonTitle.hashCode,
      title: '📖 Time to learn!',
      body: lessonTitle,
      scheduledDate: when,
    );
  }

  // Cancel notification
  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  // Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Schedule study plan reminders
  static Future<void> scheduleStudyPlanReminders(StudyPlan plan) async {
    for (var task in plan.tasks) {
      if (!task.isCompleted && task.dueDate.isAfter(DateTime.now())) {
        // Remind 1 hour before due time
        final reminderTime = task.dueDate.subtract(const Duration(hours: 1));

        if (reminderTime.isAfter(DateTime.now())) {
          await scheduleStudyReminder(
            id: task.id.hashCode,
            title: '⏰ Study Task Due Soon',
            body: '${task.title} is due in 1 hour',
            scheduledDate: reminderTime,
          );
        }
      }
    }
  }
}
