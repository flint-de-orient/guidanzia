import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';

/// Thin wrapper around flutter_local_notifications for the PDF "download"
/// experience: a staged progress notification (no fake byte %), a completion
/// notification that opens the file on tap, and the native "Open with" chooser.
class DownloadNotifier {
  DownloadNotifier._();
  static final DownloadNotifier instance = DownloadNotifier._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'downloads';
  static const _channelName = 'Downloads';
  static const int notifId = 1001;

  /// Initialise once and request the Android-13+ notification permission.
  Future<void> init() async {
    if (_ready) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: android),
      onDidReceiveNotificationResponse: (resp) {
        final path = resp.payload;
        if (path != null && path.isNotEmpty) OpenFilex.open(path);
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _ready = true;
  }

  AndroidNotificationDetails _progressDetails(String stage) =>
      AndroidNotificationDetails(
        _channelId, _channelName,
        channelDescription: 'Report downloads',
        importance: Importance.low,
        priority: Priority.low,
        onlyAlertOnce: true,
        ongoing: true,
        showProgress: true,
        indeterminate: true, // staged, honest — no fabricated byte percentage
        subText: stage,
      );

  /// Update the ongoing "downloading" notification with the current stage.
  Future<void> showProgress(String stage) async {
    await init();
    await _plugin.show(
      notifId,
      'Downloading your report…',
      stage,
      NotificationDetails(android: _progressDetails(stage)),
    );
  }

  /// Replace the progress notification with a tappable "downloaded" one whose
  /// tap opens [filePath].
  Future<void> showComplete(String filePath) async {
    await init();
    await _plugin.show(
      notifId,
      'Report downloaded',
      'Tap to open your career report',
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          channelDescription: 'Report downloads',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
          autoCancel: true,
        ),
      ),
      payload: filePath,
    );
  }

  Future<void> showFailed() async {
    await init();
    await _plugin.show(
      notifId,
      'Download failed',
      "Couldn't generate the report. Please try again.",
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          ongoing: false,
        ),
      ),
    );
  }
}
