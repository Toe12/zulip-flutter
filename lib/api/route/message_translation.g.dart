// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: constant_identifier_names, unnecessary_cast

part of 'message_translation.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TranslateMessageResult _$TranslateMessageResultFromJson(
  Map<String, dynamic> json,
) => TranslateMessageResult(
  source: json['source'] as String?,
  target: json['target'] as String,
  sameLanguage: json['same_language'] as bool,
  content: json['content'] as String?,
  strings: (json['strings'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(k, e as String),
  ),
);

Map<String, dynamic> _$TranslateMessageResultToJson(
  TranslateMessageResult instance,
) => <String, dynamic>{
  'source': instance.source,
  'target': instance.target,
  'same_language': instance.sameLanguage,
  'content': instance.content,
  'strings': instance.strings,
};
