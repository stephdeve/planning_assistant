// ============================================================
// SERVICE DE PERMISSIONS — COUCHE SERVICE
// Centralise la demande et vérification de toutes les
// permissions requises par l'application.
// Principe : demander les permissions au bon moment,
// expliquer pourquoi (best practice Android/iOS).
// ============================================================

import 'package:permission_handler/permission_handler.dart';

/// Résultat global de la vérification des permissions
class PermissionStatus {
  final bool notifications;
  final bool microphone;
  final bool scheduleExactAlarms; // Android 12+ uniquement

  const PermissionStatus({
    required this.notifications,
    required this.microphone,
    required this.scheduleExactAlarms,
  });

  /// Toutes les permissions critiques sont accordées
  bool get allGranted => notifications && microphone;

  /// Résumé lisible pour l'UI
  String get summary {
    final missing = <String>[];
    if (!notifications) missing.add('Notifications');
    if (!microphone) missing.add('Microphone');
    if (missing.isEmpty) return 'Toutes les permissions sont accordées';
    return 'Permissions manquantes : ${missing.join(', ')}';
  }
}

/// Service unifié de gestion des permissions.
class PermissionService {
  /// Demande toutes les permissions nécessaires en une seule fois.
  /// À appeler au premier lancement de l'application.
  Future<PermissionStatus> requestAllPermissions() async {
    // Demander plusieurs permissions en parallèle (plus rapide)
    final results = await [
      Permission.notification,
      Permission.microphone,
    ].request();

    // Vérifier séparément les alarmes exactes (Android 12+)
    final exactAlarms = await Permission.scheduleExactAlarm.status;
    if (!exactAlarms.isGranted) {
      await Permission.scheduleExactAlarm.request();
    }

    return PermissionStatus(
      notifications: results[Permission.notification]?.isGranted ?? false,
      microphone: results[Permission.microphone]?.isGranted ?? false,
      scheduleExactAlarms:
          (await Permission.scheduleExactAlarm.status).isGranted,
    );
  }

  /// Vérifie l'état actuel des permissions sans les demander.
  /// Utile au démarrage pour savoir si tout est en ordre.
  Future<PermissionStatus> checkPermissions() async {
    return PermissionStatus(
      notifications: await Permission.notification.isGranted,
      microphone: await Permission.microphone.isGranted,
      scheduleExactAlarms: await Permission.scheduleExactAlarm.isGranted,
    );
  }

  /// Ouvre les paramètres de l'application si une permission a été refusée
  /// définitivement (l'utilisateur a coché "Ne plus demander").
  Future<bool> openAppSettings() async {
    return await openAppSettings();
  }

  /// Demande uniquement la permission microphone (pour la reconnaissance vocale)
  Future<bool> requestMicrophonePermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Demande uniquement la permission notifications
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Vérifie si la permission microphone est accordée
  Future<bool> get hasMicrophonePermission =>
      Permission.microphone.isGranted;

  /// Vérifie si les notifications sont autorisées
  Future<bool> get hasNotificationPermission =>
      Permission.notification.isGranted;
}
