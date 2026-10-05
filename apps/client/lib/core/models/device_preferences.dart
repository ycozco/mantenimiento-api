class DevicePreferences {
  final String themeMode; // 'dark', 'light', 'system'
  final bool notificationsEnabled;
  final bool compactView;
  final String? lastScreen;

  const DevicePreferences({
    this.themeMode = 'dark',
    this.notificationsEnabled = true,
    this.compactView = false,
    this.lastScreen,
  });

  DevicePreferences copyWith({
    String? themeMode,
    bool? notificationsEnabled,
    bool? compactView,
    String? lastScreen,
  }) {
    return DevicePreferences(
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      compactView: compactView ?? this.compactView,
      lastScreen: lastScreen ?? this.lastScreen,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode,
      'notificationsEnabled': notificationsEnabled,
      'compactView': compactView,
      'lastScreen': lastScreen,
    };
  }

  factory DevicePreferences.fromJson(Map<String, dynamic> json) {
    return DevicePreferences(
      themeMode: json['themeMode'] as String? ?? 'dark',
      notificationsEnabled: json['notificationsEnabled'] as bool? ?? true,
      compactView: json['compactView'] as bool? ?? false,
      lastScreen: json['lastScreen'] as String?,
    );
  }
}
