class UserPreference {
  final int? prefId;
  final String sourceLanguageCode;   // new field
  final String targetLanguageCode;   // new field
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

  factory UserPreference.fromMap(Map<String, dynamic> map) {
    return UserPreference(
      prefId: map['pref_id'],
      sourceLanguageCode: map['source_language_code'],
      targetLanguageCode: map['target_language_code'],
      fontSizeScale: map['font_size_scale'],
      overlayOpacity: map['overlay_opacity'],
      textColorHex: map['text_color_hex'],
      bgColorHex: map['bg_color_hex'],
      isTutorialCompleted:
      map['is_tutorial_completed'] == 1 || map['is_tutorial_completed'] == true,
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