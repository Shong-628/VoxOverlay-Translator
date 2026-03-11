class LanguageModel {
  final String modelId;
  final String sourceLangCode;
  final String targetLangCode;
  final String displayName;
  final String filePathUri;
  final bool isDownloaded;
  final String version;

  LanguageModel({
    required this.modelId,
    required this.sourceLangCode,
    required this.targetLangCode,
    required this.displayName,
    required this.filePathUri,
    required this.isDownloaded,
    required this.version,
  });

  factory LanguageModel.fromMap(Map<String, dynamic> map) {
    return LanguageModel(
      modelId: map['model_id'],
      sourceLangCode: map['source_lang_code'],
      targetLangCode: map['target_lang_code'],
      displayName: map['display_name'],
      filePathUri: map['file_path_uri'],
      isDownloaded: map['is_downloaded'] == 1 || map['is_downloaded'] == true,
      version: map['version'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'model_id': modelId,
      'source_lang_code': sourceLangCode,
      'target_lang_code': targetLangCode,
      'display_name': displayName,
      'file_path_uri': filePathUri,
      'is_downloaded': isDownloaded ? 1 : 0,
      'version': version,
    };
  }
}