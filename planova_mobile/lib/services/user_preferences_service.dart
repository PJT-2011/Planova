import 'package:shared_preferences/shared_preferences.dart';

/// Small local-only display preferences that don't need a Firestore
/// round-trip — currently just whether off-limits areas on the floor map
/// should be blurred. Stored per-device via shared_preferences, the same
/// way RecentBuildingService and the onboarding flag are.
///
/// This is deliberately separate from [AccessControlService] /
/// [BuildingService]: whether an area is off-limits (and therefore
/// unreachable) is server-side and shared by everyone. Whether *this*
/// user's screen blurs the pixels over that area is a personal display
/// preference and never changes what's actually restricted.
class UserPreferencesService {
  static String _blurKey(String userId) => 'offlimits_blur_$userId';

  /// Defaults to blurred — the safer default for a first-time viewer who
  /// hasn't chosen a preference yet.
  Future<bool> getOffLimitsBlurEnabled(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_blurKey(userId)) ?? true;
  }

  Future<void> setOffLimitsBlurEnabled(String userId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_blurKey(userId), enabled);
  }
}
