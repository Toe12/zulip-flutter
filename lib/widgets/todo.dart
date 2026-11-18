import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../api/exception.dart';
import '../api/model/submessage.dart';
import '../api/route/submessage.dart';
import '../generated/l10n/zulip_localizations.dart';
import '../model/binding.dart';
import '../model/message_translation.dart';
import 'content.dart';
import 'dialog.dart';
import 'message_translation.dart';
import 'store.dart';
import 'text.dart';

class TodoWidget extends StatefulWidget {
  const TodoWidget({
    super.key,
    required this.messageId,
    required this.todoList,
    this.translation,
  });

  final int messageId;
  final TodoList todoList;

  /// The translation to show the list's text in, if any.
  final MessageTranslation? translation;

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  @override
  void initState() {
    super.initState();
    widget.todoList.addListener(_modelChanged);
  }

  @override
  void didUpdateWidget(covariant TodoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.todoList != oldWidget.todoList) {
      oldWidget.todoList.removeListener(_modelChanged);
      widget.todoList.addListener(_modelChanged);
    }
  }

  @override
  void dispose() {
    widget.todoList.removeListener(_modelChanged);
    super.dispose();
  }

  void _modelChanged() {
    setState(() {
      // The actual state lives in the [TodoList] model.
      // This method was called because that just changed.
    });
  }

  Future<void> _send(TodoEventSubmessage event) async {
    final store = PerAccountStoreWidget.of(context);
    final zulipLocalizations = ZulipLocalizations.of(context);
    try {
      await sendSubmessage(store.connection, messageId: widget.messageId,
        submessageType: SubmessageType.widget,
        content: event);
    } catch (e) {
      if (!mounted) return;
      showErrorDialog(context: context,
        title: zulipLocalizations.errorTodoUpdateFailedTitle,
        message: e is ZulipApiException ? e.message : null);
    }
  }

  void _showLockReason(String reason) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(reason)));
  }

  /// Re-translate if tasks were added since the list was translated.
  void _maybeTranslateNewStrings() {
    final translation = widget.translation;
    if (translation == null || translation.loading) return;
    bool hasNewStrings() => todoListStrings(widget.todoList)
      .any((s) => !translation.requestedStrings.contains(s));
    if (!hasNewStrings()) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted || translation.loading || !hasNewStrings()) return;
      if (!identical(widget.translation, translation)) return;
      unawaited(translateMessageWithFeedback(context,
        message: InheritedMessage.of(context), target: translation.target));
    });
  }

  @override
  Widget build(BuildContext context) {
    const verticalPadding = 2.5;

    final store = PerAccountStoreWidget.of(context);
    final zulipLocalizations = ZulipLocalizations.of(context);
    final theme = Theme.of(context);
    final todoList = widget.todoList;
    final translation = widget.translation;
    String tr(String text) => translation?.translateString(text) ?? text;
    _maybeTranslateNewStrings();

    final textStyleBold = weightVariableTextStyle(context, wght: 600);
    final textStyleDesc = TextStyle(fontSize: 14, color: theme.hintColor);

    final now = ZulipBinding.instance.utcNow();
    final assignee = todoList.assignee;
    final hasAssignee = assignee != null;
    final isMyList = todoList.messageSenderId == store.selfUserId;
    final isMyAssignment = assignee?.userId == store.selfUserId;

    Text title = (todoList.taskListTitle.isNotEmpty)
      ? Text(tr(todoList.taskListTitle), style: textStyleBold.copyWith(fontSize: 18))
      : Text(zulipLocalizations.todoWidgetTitleMissing,
          style: textStyleBold.copyWith(fontSize: 18));

    Widget buildTaskItem(TodoTask task) {
      final strikethroughStyle = task.completed
        ? TextDecoration.lineThrough
        : TextDecoration.none;
      final textColor = task.completed ? theme.hintColor : null;

      // These rules match the web client's (todo_data.ts);
      // the server enforces them too.
      final mustStart = hasAssignee && !task.completed && !task.inProgress;
      final String? lockReason;
      if (task.completed && todoList.isUncheckRestricted(store.selfUserId)) {
        lockReason = zulipLocalizations.todoWidgetUncheckRestricted;
      } else if (mustStart) {
        lockReason = zulipLocalizations.todoWidgetMustStartFirst;
      } else {
        lockReason = null;
      }
      final canStart = mustStart && isMyAssignment;
      final canReset = hasAssignee && isMyList && (task.completed || task.inProgress);

      final statusIcon = task.completed ? '✅'
        : task.inProgress ? '🔧'
        : task.isOverdue(now) ? '⚠️'
        : '⏳';

      final checkboxColor = lockReason != null
        ? theme.disabledColor
        : task.completed ? theme.colorScheme.primary : theme.hintColor;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                end: 5, top: verticalPadding, bottom: verticalPadding),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: lockReason != null
                    ? () => _showLockReason(lockReason!)
                    : () => _send(TodoStrikeEventSubmessage(key: task.key)),
                  child: Center(
                    child: Icon(
                      task.completed
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                      color: checkboxColor,
                      size: 22)))))),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: verticalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(TextSpan(children: [
                    TextSpan(text: '$statusIcon '),
                    TextSpan(text: tr(task.task),
                      style: TextStyle(decoration: strikethroughStyle)),
                  ]),
                    style: textStyleBold.copyWith(fontSize: 16, color: textColor)),
                  if (task.desc.isNotEmpty)
                    Text(tr(task.desc),
                      style: textStyleDesc.copyWith(decoration: strikethroughStyle)),
                  if (task.deadline.isNotEmpty || (task.inProgress && !task.completed))
                    Text.rich(TextSpan(children: [
                      if (task.deadline.isNotEmpty)
                        TextSpan(text: '(${task.deadline})'),
                      if (task.deadline.isNotEmpty && task.inProgress && !task.completed)
                        const TextSpan(text: ' '),
                      if (task.inProgress && !task.completed)
                        TextSpan(text: zulipLocalizations.todoWidgetTaskInProgress,
                          style: TextStyle(fontStyle: FontStyle.italic,
                            color: theme.colorScheme.primary)),
                    ]),
                      style: textStyleDesc.copyWith(fontSize: 13)),
                ]))),
          if (canStart)
            Padding(
              padding: const EdgeInsets.only(top: verticalPadding),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12)),
                onPressed: () => _send(TodoStartTaskEventSubmessage(key: task.key)),
                child: Text(zulipLocalizations.todoWidgetStartTask))),
          if (canReset)
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: zulipLocalizations.todoWidgetResetTask,
              icon: Icon(Icons.undo, size: 20, color: theme.hintColor),
              onPressed: () => _send(TodoResetTaskEventSubmessage(key: task.key))),
        ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        title,
        if (assignee != null)
          Text(zulipLocalizations.todoWidgetAssignedTo(
              store.getUser(assignee.userId)?.fullName ?? assignee.email),
            style: textStyleDesc.copyWith(fontSize: 13)),
        const SizedBox(height: 6 - verticalPadding),
        if (todoList.tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: verticalPadding),
            child: Text(zulipLocalizations.todoWidgetTasksMissing,
              style: textStyleDesc.copyWith(fontStyle: FontStyle.italic))),
        for (final task in todoList.tasks)
          buildTaskItem(task),
        const SizedBox(height: 5 - verticalPadding),
      ]);
  }
}
