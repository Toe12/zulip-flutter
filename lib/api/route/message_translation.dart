import 'package:json_annotation/json_annotation.dart';

import '../core.dart';

part 'message_translation.g.dart';

/// Translate a message, or the strings of its to-do list.
///
/// A local server addition, not in upstream Zulip:
/// POST /messages/{message_id}/translate, backed by LibreTranslate.
/// Supported languages are "en", "es" and "id".
Future<TranslateMessageResult> translateMessage(ApiConnection connection, {
  required int messageId,
  required String target,
  String? source,
}) {
  return connection.post('translateMessage', TranslateMessageResult.fromJson,
    'messages/$messageId/translate', {
      'target': RawParameter(target),
      if (source != null) 'source': RawParameter(source),
    });
}

@JsonSerializable(fieldRename: FieldRename.snake)
class TranslateMessageResult {
  /// The detected (or given) source language, or null if undetected.
  final String? source;
  final String target;

  /// True if the message is already in [target] (or has nothing to
  /// translate); then [content] and [strings] are null.
  final bool sameLanguage;

  /// The translated HTML, for a regular message.
  final String? content;

  /// Original-to-translated strings, for a to-do list.
  final Map<String, String>? strings;

  TranslateMessageResult({
    required this.source,
    required this.target,
    required this.sameLanguage,
    required this.content,
    required this.strings,
  });

  factory TranslateMessageResult.fromJson(Map<String, dynamic> json) =>
    _$TranslateMessageResultFromJson(json);

  Map<String, dynamic> toJson() => _$TranslateMessageResultToJson(this);
}
