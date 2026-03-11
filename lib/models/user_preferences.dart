class UserPreferences {

  String language;
  double fontSize;
  double opacity;
  bool darkMode;
  bool onboardingCompleted;

  UserPreferences({
    required this.language,
    required this.fontSize,
    required this.opacity,
    required this.darkMode,
    required this.onboardingCompleted,
  });
}