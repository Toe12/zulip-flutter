import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../api/model/model.dart';
import '../api/model/submessage.dart';
import '../log.dart';
import '../model/message_translation.dart';
import 'icons.dart';
import 'store.dart';

/// The strings of a to-do list that get translated:
/// its title and its tasks' names and descriptions.
List<String> todoListStrings(TodoList todoList) => [
  todoList.taskListTitle,
  for (final task in todoList.tasks) ...[task.task, task.desc],
].where((s) => s.trim().isNotEmpty).toList();

/// Show [message] translated, reporting any failure to the user.
Future<void> translateMessageWithFeedback(BuildContext context, {
  required Message message,
  required TranslationLanguage target,
}) async {
  final store = PerAccountStoreWidget.of(context);
  final todoList = message.todoList;
  try {
    await store.messageTranslations.translate(store, message, target,
      todoStrings: todoList == null ? const [] : todoListStrings(todoList));
  } catch (e) {
    reportErrorToUserBriefly(_uiText[target]!.failed);
  }
}

/// Show [message] translated, or back to the original if it already is.
void toggleMessageTranslation(BuildContext context, Message message) {
  final translations = PerAccountStoreWidget.of(context).messageTranslations;
  if (translations[message.id] != null) {
    translations.showOriginal(message.id);
    return;
  }
  final uiLanguage = Localizations.localeOf(context).languageCode;
  unawaited(translateMessageWithFeedback(context,
    message: message, target: translations.defaultTarget(uiLanguage)));
}

/// A button that toggles [message] between translated and original.
class MessageTranslateIconButton extends StatelessWidget {
  const MessageTranslateIconButton({super.key, required this.message, required this.color});

  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final translations = PerAccountStoreWidget.of(context).messageTranslations;
    final activeColor = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: translations,
      builder: (context, _) {
        final isTranslated = translations[message.id] != null;
        return Semantics(
          button: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => toggleMessageTranslation(context, message),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Icon(ZulipIcons.language, size: 16,
                color: isTranslated ? activeColor : color))));
      });
  }
}

/// The text of the translation bar.
///
/// The bar is written in the language being translated into,
/// as the web client does, since that's the language the reader understands.
/// (The app's own translations don't have Indonesian.)
class _TranslationUiText {
  const _TranslationUiText({
    required this.names,
    required this.translatedFrom,
    required this.alreadyIn,
    required this.showOriginal,
    required this.translating,
    required this.failed,
    required this.translateTo,
  });

  final Map<TranslationLanguage, String> names;
  final String Function(String language) translatedFrom;
  final String Function(String language) alreadyIn;
  final String showOriginal;
  final String translating;
  final String failed;
  final String translateTo;
}

final Map<TranslationLanguage, _TranslationUiText> _uiText = {
  TranslationLanguage.en: _TranslationUiText(
    names: {TranslationLanguage.en: 'English', TranslationLanguage.es: 'Spanish', TranslationLanguage.id: 'Indonesian'},
    translatedFrom: (lang) => 'Translated from $lang',
    alreadyIn: (lang) => 'Already in $lang',
    showOriginal: 'Show original',
    translating: 'Translating…',
    failed: 'Translation failed',
    translateTo: 'Translate to',
  ),
  TranslationLanguage.es: _TranslationUiText(
    names: {TranslationLanguage.en: 'inglés', TranslationLanguage.es: 'español', TranslationLanguage.id: 'indonesio'},
    translatedFrom: (lang) => 'Traducido del $lang',
    alreadyIn: (lang) => 'Ya está en $lang',
    showOriginal: 'Ver original',
    translating: 'Traduciendo…',
    failed: 'No se pudo traducir',
    translateTo: 'Traducir a',
  ),
  TranslationLanguage.id: _TranslationUiText(
    names: {TranslationLanguage.en: 'Inggris', TranslationLanguage.es: 'Spanyol', TranslationLanguage.id: 'Indonesia'},
    translatedFrom: (lang) => 'Diterjemahkan dari bahasa $lang',
    alreadyIn: (lang) => 'Sudah dalam bahasa $lang',
    showOriginal: 'Lihat asli',
    translating: 'Menerjemahkan…',
    failed: 'Gagal menerjemahkan',
    translateTo: 'Terjemahkan ke',
  ),
};

/// The bar above a translated message:
/// where it was translated from, a way back to the original,
/// and a picker for another language.
///
/// Also re-translates the message if it gets edited.
class MessageTranslationBar extends StatefulWidget {
  const MessageTranslationBar({super.key, required this.message, required this.translation});

  final Message message;
  final MessageTranslation translation;

  @override
  State<MessageTranslationBar> createState() => _MessageTranslationBarState();
}

class _MessageTranslationBarState extends State<MessageTranslationBar> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeRefresh();
  }

  @override
  void didUpdateWidget(covariant MessageTranslationBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeRefresh();
  }

  bool get _isStale => !widget.translation.loading
    && widget.translation.originalContent != widget.message.content;

  void _maybeRefresh() {
    if (!_isStale) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_isStale) return;
      unawaited(translateMessageWithFeedback(context,
        message: widget.message, target: widget.translation.target));
    });
  }

  @override
  Widget build(BuildContext context) {
    final translation = widget.translation;
    final text = _uiText[translation.target]!;
    final store = PerAccountStoreWidget.of(context);
    final theme = Theme.of(context);
    final style = TextStyle(fontSize: 13, height: 1.3, color: theme.hintColor);

    final String status;
    if (translation.loading) {
      status = text.translating;
    } else if (translation.sameLanguage) {
      status = text.alreadyIn(text.names[translation.target]!);
    } else if (translation.source case final source?) {
      status = text.translatedFrom(text.names[source]!);
    } else {
      status = '';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: DefaultTextStyle(
        style: style,
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ZulipIcons.language, size: 14, color: theme.hintColor),
              const SizedBox(width: 4),
              Text(status),
            ]),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => store.messageTranslations.showOriginal(widget.message.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(text.showOriginal,
                  style: style.copyWith(color: theme.colorScheme.primary)))),
            PopupMenuButton<TranslationLanguage>(
              tooltip: text.translateTo,
              initialValue: translation.target,
              onSelected: (target) => unawaited(translateMessageWithFeedback(context,
                message: widget.message, target: target)),
              itemBuilder: (context) => [
                for (final language in TranslationLanguage.values)
                  PopupMenuItem(value: language,
                    child: Text('${language.name.toUpperCase()} · ${text.names[language]}')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(translation.target.name.toUpperCase(),
                    style: style.copyWith(color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600)),
                  Icon(Icons.arrow_drop_down, size: 18, color: theme.colorScheme.primary),
                ]))),
          ])));
  }
}
