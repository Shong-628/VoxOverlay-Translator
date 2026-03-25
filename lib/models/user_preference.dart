class UserPreference {
  final int? prefId;
  final String sourceLanguageCode;
  final String targetLanguageCode;
  final double fontSizeScale;
  final int overlayOpacity;
  final String textColorHex;
  final String bgColorHex;
  final bool isTutorialCompleted;

  UserPreference({
    this.prefId,
    required this.sourceLanguageCode,
    required this.targetLanguageCode,
    required this.fontSizeScale,
    required this.overlayOpacity,
    required this.textColorHex,
    required this.bgColorHex,
    this.isTutorialCompleted = false,
  });

  UserPreference copyWith({
    int? prefId,
    String? sourceLanguageCode,
    String? targetLanguageCode,
    double? fontSizeScale,
    int? overlayOpacity,
    String? textColorHex,
    String? bgColorHex,
    bool? isTutorialCompleted,
  }) {
    return UserPreference(
      prefId: prefId ?? this.prefId,
      sourceLanguageCode: sourceLanguageCode ?? this.sourceLanguageCode,
      targetLanguageCode: targetLanguageCode ?? this.targetLanguageCode,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      textColorHex: textColorHex ?? this.textColorHex,
      bgColorHex: bgColorHex ?? this.bgColorHex,
      isTutorialCompleted: isTutorialCompleted ?? this.isTutorialCompleted,
    );
  }

  factory UserPreference.fromMap(Map<String, dynamic> map) {
    return UserPreference(
      prefId: map['pref_id'],
      sourceLanguageCode: map['source_language_code'],
      targetLanguageCode: map['target_language_code'],

      // Safely parse as num first, then convert to double.
      // Added a fallback of 14.0 just in case the value is completely missing.
      fontSizeScale: (map['font_size_scale'] as num?)?.toDouble() ?? 14.0,
      overlayOpacity: (map['overlay_opacity'] as num?)?.toInt() ?? 100,

      textColorHex: map['text_color_hex'],
      bgColorHex: map['bg_color_hex'],
      isTutorialCompleted: map['is_tutorial_completed'] == 1 || map['is_tutorial_completed'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pref_id': prefId,
      'source_language_code': sourceLanguageCode,
      'target_language_code': targetLanguageCode,
      'font_size_scale': fontSizeScale,
      'overlay_opacity': overlayOpacity,
      'text_color_hex': textColorHex,
      'bg_color_hex': bgColorHex,
      'is_tutorial_completed': isTutorialCompleted ? 1 : 0,
    };
  }
}
