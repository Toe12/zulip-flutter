import 'dart:async';

import 'package:flutter/foundation.dart';

import '../api/model/model.dart';
import '../api/route/message_translation.dart';
import 'content.dart';
import 'store.dart';

/// A language messages can be translated to or from.
///
/// These are the languages the server's translation endpoint supports;
/// see [translateMessage].
enum TranslationLanguage {
  en,
  es,
  id;

  static TranslationLanguage? fromCode(String? code) =>
    values.where((l) => l.name == code).firstOrNull;
}

/// The translation shown in place of one message's content.
class MessageTranslation {
  MessageTranslation._({required this.target, required this.originalContent});

  final TranslationLanguage target;

  /// [Message.content] when the translation was requested,
  /// to notice when the message gets edited.
  final String originalContent;

  bool loading = true;
  TranslationLanguage? source;

  /// True if the message was already in [target].
  bool sameLanguage = false;

  /// The translated content, for a regular message.
  ZulipContent? content;

  /// Original-to-translated strings, for a to-do list.
  Map<String, String> strings = {};

  /// To-do list strings already sent for translation,
  /// so a string the server leaves alone doesn't cause a request loop.
  final Set<String> requestedStrings = {};

  /// The translation of a to-do list string, or the string itself.
  String translateString(String text) =>
    strings[text] ?? strings[text.trim()] ?? text;
}

/// The messages shown translated, for one account.
///
/// This state is in memory only; it's lost when the store is replaced.
class MessageTranslations extends ChangeNotifier {
  final Map<int, MessageTranslation> _byMessageId = {};

  /// The language last picked, to default to for the next translation.
  TranslationLanguage? lastTarget;

  MessageTranslation? operator [](int messageId) => _byMessageId[messageId];

  /// The language to translate to by default,
  /// given the language of the app's UI.
  TranslationLanguage defaultTarget(String uiLanguageCode) =>
    lastTarget ?? TranslationLanguage.fromCode(uiLanguageCode) ?? TranslationLanguage.en;

  /// Show [message] translated to [target], fetching the translation.
  ///
  /// [todoStrings] are the to-do list's current strings, if it has one.
  /// On failure, goes back to showing the original, and rethrows.
  Future<void> translate(PerAccountStore store, Message message, TranslationLanguage target, {
    Iterable<String> todoStrings = const [],
  }) async {
    lastTarget = target;
    final translation = MessageTranslation._(target: target,
      originalContent: message.content);
    translation.requestedStrings.addAll(todoStrings);
    final previous = _byMessageId[message.id];
    if (previous != null && previous.target == target) {
      // Keep showing the strings we have while re-requesting.
      translation.strings = previous.strings;
    }
    _byMessageId[message.id] = translation;
    notifyListeners();

    final TranslateMessageResult result;
    try {
      result = await translateMessage(store.connection,
        messageId: message.id, target: target.name);
    } catch (e) {
      if (identical(_byMessageId[message.id], translation)) {
        _byMessageId.remove(message.id);
        notifyListeners();
      }
      rethrow;
    }
    if (!identical(_byMessageId[message.id], translation)) return;

    translation
      ..loading = false
      ..source = TranslationLanguage.fromCode(result.source)
      ..sameLanguage = result.sameLanguage
      ..content = result.content == null ? null : parseContent(result.content!)
      ..strings = {...translation.strings, ...?result.strings};
    notifyListeners();
  }

  /// Go back to showing the original content of the given message.
  void showOriginal(int messageId) {
    if (_byMessageId.remove(messageId) != null) notifyListeners();
  }
}

final _messageTranslationsExpando = Expando<MessageTranslations>();

extension PerAccountStoreMessageTranslations on PerAccountStore {
  MessageTranslations get messageTranslations =>
    _messageTranslationsExpando[this] ??= MessageTranslations();
}
