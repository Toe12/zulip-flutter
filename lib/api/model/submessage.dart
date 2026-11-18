import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

import '../../log.dart';
import 'events.dart';

part 'submessage.g.dart';

/// Data used for Zulip "widgets" within messages, like polls and todo lists.
///
/// For docs, see:
///   https://zulip.com/api/get-messages#response (search for "submessage")
///   https://zulip.readthedocs.io/en/latest/subsystems/widgets.html
///
/// This is an underdocumented part of the Zulip Server API.
/// So in addition to docs, see other clients:
///   https://github.com/zulip/zulip-mobile/blob/2217c858e/src/api/modelTypes.js#L800-L861
///   https://github.com/zulip/zulip-mobile/blob/2217c858e/src/webview/html/message.js#L118-L192
///   https://github.com/zulip/zulip/blob/40f59a05c/web/src/submessage.ts
///   https://github.com/zulip/zulip/blob/40f59a05c/web/shared/src/poll_data.ts
@JsonSerializable(fieldRename: FieldRename.snake)
class Submessage {
  const Submessage({
    required this.senderId,
    required this.msgType,
    required this.content,
  });

  // TODO(server): should we be sorting a message's submessages by ID?  Web seems to:
  //   https://github.com/zulip/zulip/blob/40f59a05c55e0e4f26ca87d2bca646770e94bff0/web/src/submessage.ts#L88
  // final int id;  // ignored because we don't use it

  /// The sender of this submessage (not necessarily of the [Message] it's on).
  final int senderId;

  // final int messageId;  // ignored; redundant with [Message.id]

  @JsonKey(unknownEnumValue: SubmessageType.unknown)
  final SubmessageType msgType;

  /// A JSON encoding of a [SubmessageData].
  // We cannot parse the String into one of the [SubmessageData] classes because
  // information from other submessages are required. Specifically, we need:
  //   * the index of this submessage in [Message.submessages];
  //   * the parsed [WidgetType] from the first [Message.submessages].
  final String content;

  /// Parse a JSON list into a [Poll] or a [TodoList], as appropriate.
  static Object? parseSubmessagesJson(List<Object?> json, {
    required int messageSenderId,
  }) {
    final submessages = json.map((e) => Submessage.fromJson(e as Map<String, Object?>)).toList();
    if (submessages.isEmpty) return null;

    assert(submessages.first.senderId == messageSenderId);

    final widgetData = WidgetData.fromJson(jsonDecode(submessages.first.content));
    switch (widgetData) {
      case PollWidgetData():
        return Poll.fromSubmessages(
          widgetData: widgetData,
          pollEventSubmessages: submessages.skip(1),
          messageSenderId: messageSenderId,
          debugSubmessages: kDebugMode ? submessages : null,
        );
      case TodoWidgetData():
        return TodoList.fromSubmessages(
          widgetData: widgetData,
          todoEventSubmessages: submessages.skip(1),
          messageSenderId: messageSenderId,
          debugSubmessages: kDebugMode ? submessages : null,
        );
      case UnsupportedWidgetData():
        assert(debugLog('Unsupported widgetData: ${widgetData.json}'));
        return null;
    }
  }

  factory Submessage.fromJson(Map<String, Object?> json) =>
    _$SubmessageFromJson(json);

  Map<String, Object?> toJson() => _$SubmessageToJson(this);
}

/// As in [Submessage.msgType].
///
/// The only type of submessage that actually exists in Zulip (as of 2024,
/// and since this "submessages" subsystem was created in 2017–2018)
/// is [SubmessageType.widget].
@JsonEnum(fieldRename: FieldRename.snake, alwaysCreate: true)
enum SubmessageType {
  widget,
  unknown;

  String toJson() => _$SubmessageTypeEnumMap[this]!;
}

/// The data encoded in a submessage at [Submessage.content].
///
/// For widgets (the only existing use of submessages), the submessages
/// on a [Message] consist of:
///  * One submessage with content [WidgetData]; then
///  * Zero or more submessages with content [PollEventSubmessage] if the
///    message is a poll (i.e. if the first submessage was a [PollWidgetData]),
///    and similarly for other types of widgets.
sealed class SubmessageData {
  Object? toJson();
}

/// The data encoded in a submessage to make the message a Zulip widget.
///
/// Expected from the first [Submessage.content] in the "submessages" field on
/// the message when there is an widget.
///
/// See https://zulip.readthedocs.io/en/latest/subsystems/widgets.html
sealed class WidgetData extends SubmessageData {
  WidgetType get widgetType;

  WidgetData();

  factory WidgetData.fromJson(Object? json) {
    final map = json as Map<String, Object?>;
    final rawWidgetType = map['widget_type'] as String;
    return switch (WidgetType.fromRawString(rawWidgetType)) {
      WidgetType.poll => PollWidgetData.fromJson(map),
      WidgetType.todo => TodoWidgetData.fromJson(map),
      WidgetType.unknown => UnsupportedWidgetData.fromJson(map),
    };
  }

  @override
  Object? toJson();
}

/// As in [WidgetData.widgetType].
@JsonEnum(alwaysCreate: true)
enum WidgetType {
  poll,
  todo,
  // zform,  // This exists in web but is more a demo than a real feature.
  unknown;

  static WidgetType fromRawString(String raw) => _byRawString[raw] ?? unknown;

  static final _byRawString = _$WidgetTypeEnumMap
    .map((key, value) => MapEntry(value, key));
}

/// The data in the first submessage on a poll widget message.
///
/// Subsequent submessages on the same message will be [PollEventSubmessage].
@JsonSerializable(fieldRename: FieldRename.snake)
class PollWidgetData extends WidgetData {
  @override
  @JsonKey(includeToJson: true)
  WidgetType get widgetType => WidgetType.poll;

  /// The initial question and options on the poll.
  final PollWidgetExtraData extraData;

  PollWidgetData({required this.extraData});

  factory PollWidgetData.fromJson(Map<String, Object?> json) =>
    _$PollWidgetDataFromJson(json);

  @override
  Map<String, Object?> toJson() => _$PollWidgetDataToJson(this);
}

/// As in [PollWidgetData.extraData].
@JsonSerializable(fieldRename: FieldRename.snake)
class PollWidgetExtraData {
  // The [question] and [options] fields seem to be always present.
  // But both web and zulip-mobile accept them as optional, with default values:
  //   https://github.com/zulip/zulip-flutter/pull/823#discussion_r1697656896
  //   https://github.com/zulip/zulip/blob/40f59a05c55e0e4f26ca87d2bca646770e94bff0/web/src/poll_widget.ts#L29
  // And the server doesn't really enforce any structure on submessage data.
  // So match the web and zulip-mobile behavior.
  @JsonKey(defaultValue: "")
  final String question;
  @JsonKey(defaultValue: [])
  final List<String> options;

  const PollWidgetExtraData({required this.question, required this.options});

  factory PollWidgetExtraData.fromJson(Map<String, Object?> json) =>
    _$PollWidgetExtraDataFromJson(json);

  Map<String, Object?> toJson() => _$PollWidgetExtraDataToJson(this);
}

class UnsupportedWidgetData extends WidgetData {
  @override
  @JsonKey(includeToJson: true)
  WidgetType get widgetType => WidgetType.unknown;

  final Object? json;

  UnsupportedWidgetData.fromJson(this.json);

  @override
  Object? toJson() => json;
}

/// The data in the first submessage on a to-do list widget message.
///
/// Subsequent submessages on the same message will be [TodoEventSubmessage].
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoWidgetData extends WidgetData {
  @override
  @JsonKey(includeToJson: true)
  WidgetType get widgetType => WidgetType.todo;

  /// The initial title and tasks on the to-do list.
  final TodoWidgetExtraData extraData;

  TodoWidgetData({required this.extraData});

  factory TodoWidgetData.fromJson(Map<String, Object?> json) =>
    _$TodoWidgetDataFromJson(json);

  @override
  Map<String, Object?> toJson() => _$TodoWidgetDataToJson(this);
}

/// As in [TodoWidgetData.extraData].
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoWidgetExtraData {
  // Like [PollWidgetExtraData]'s fields, these seem to always be present,
  // but other clients treat them as optional with default values, and the
  // server doesn't enforce any structure on submessage data.  So do the same.
  @JsonKey(defaultValue: "")
  final String taskListTitle;
  @JsonKey(defaultValue: [])
  final List<TodoTaskData> tasks;

  /// The user the list is shared with (by DM), if any.
  ///
  /// A local server addition, not in upstream Zulip.
  final TodoAssignee? assignee;

  const TodoWidgetExtraData({
    required this.taskListTitle,
    required this.tasks,
    required this.assignee,
  });

  factory TodoWidgetExtraData.fromJson(Map<String, Object?> json) =>
    _$TodoWidgetExtraDataFromJson(json);

  Map<String, Object?> toJson() => _$TodoWidgetExtraDataToJson(this);
}

/// One task in the initial data of a to-do list widget ([TodoWidgetExtraData]).
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoTaskData {
  final String task;
  final String desc;
  /// A date like "2026-09-20", or empty for no deadline.
  ///
  /// A local server addition, not in upstream Zulip.
  @JsonKey(defaultValue: '')
  final String deadline;

  const TodoTaskData({required this.task, required this.desc, required this.deadline});

  factory TodoTaskData.fromJson(Map<String, Object?> json) =>
    _$TodoTaskDataFromJson(json);

  Map<String, Object?> toJson() => _$TodoTaskDataToJson(this);
}

/// As in [TodoWidgetExtraData.assignee].
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoAssignee {
  final int userId;
  final String email;

  const TodoAssignee({required this.userId, required this.email});

  factory TodoAssignee.fromJson(Map<String, Object?> json) =>
    _$TodoAssigneeFromJson(json);

  Map<String, Object?> toJson() => _$TodoAssigneeToJson(this);
}

/// The data in a submessage that acts on a poll.
///
/// The first submessage on the message should be a [PollWidgetData].
sealed class PollEventSubmessage extends SubmessageData {
  PollEventSubmessageType get type;

  PollEventSubmessage();

  /// The key for identifying the [idx]'th option added by user
  /// [senderId] to a poll.
  ///
  /// For options that are a part of the initial [PollWidgetData], the
  /// [senderId] should be `null`.
  static PollOptionKey optionKey({required int? senderId, required int idx}) =>
    // "canned" is a canonical constant coined by the web client:
    //   https://github.com/zulip/zulip/blob/40f59a05c/web/shared/src/poll_data.ts#L238
    '${senderId ?? 'canned'},$idx';

  factory PollEventSubmessage.fromJson(Map<String, Object?> json) {
    final rawPollEventType = json['type'] as String;
    switch (PollEventSubmessageType.fromRawString(rawPollEventType)) {
      case PollEventSubmessageType.newOption: return PollNewOptionEventSubmessage.fromJson(json);
      case PollEventSubmessageType.question: return PollQuestionEventSubmessage.fromJson(json);
      case PollEventSubmessageType.vote: return PollVoteEventSubmessage.fromJson(json);
      case PollEventSubmessageType.unknown: return UnknownPollEventSubmessage.fromJson(json);
    }
  }

  @override
  Map<String, Object?> toJson();
}

/// As in [PollEventSubmessage.type].
@JsonEnum(fieldRename: FieldRename.snake)
enum PollEventSubmessageType {
  newOption,
  question,
  vote,
  unknown;

  static PollEventSubmessageType fromRawString(String raw) => _byRawString[raw]!;

  static final _byRawString = _$PollEventSubmessageTypeEnumMap
    .map((key, value) => MapEntry(value, key));
}

typedef PollOptionKey = String;

/// A poll event when an option is added.
///
/// See: https://github.com/zulip/zulip/blob/40f59a05c/web/shared/src/poll_data.ts#L112-L159
@JsonSerializable(fieldRename: FieldRename.snake)
class PollNewOptionEventSubmessage extends PollEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  PollEventSubmessageType get type => PollEventSubmessageType.newOption;

  final String option;
  /// A sequence number for this option, among options added to this poll
  /// by this [Submessage.senderId].
  ///
  /// See [PollEventSubmessage.optionKey].
  final int idx;

  PollNewOptionEventSubmessage({required this.option, required this.idx});

  factory PollNewOptionEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$PollNewOptionEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$PollNewOptionEventSubmessageToJson(this);
}

/// A poll event when the question has been edited.
///
/// See: https://github.com/zulip/zulip/blob/40f59a05c/web/shared/src/poll_data.ts#L161-186
@JsonSerializable(fieldRename: FieldRename.snake)
class PollQuestionEventSubmessage extends PollEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  PollEventSubmessageType get type => PollEventSubmessageType.question;

  final String question;

  PollQuestionEventSubmessage({required this.question});

  factory PollQuestionEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$PollQuestionEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$PollQuestionEventSubmessageToJson(this);
}

/// A poll event when a vote has been cast or removed.
///
/// See: https://github.com/zulip/zulip/blob/40f59a05c/web/shared/src/poll_data.ts#L188-234
@JsonSerializable(fieldRename: FieldRename.snake)
class PollVoteEventSubmessage extends PollEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  PollEventSubmessageType get type => PollEventSubmessageType.vote;

  /// The key of the affected option.
  ///
  /// See [PollEventSubmessage.optionKey].
  final PollOptionKey key;
  @JsonKey(name: 'vote', unknownEnumValue: PollVoteOp.unknown)
  final PollVoteOp op;

  PollVoteEventSubmessage({required this.key, required this.op});

  factory PollVoteEventSubmessage.fromJson(Map<String, Object?> json) {
    final result = _$PollVoteEventSubmessageFromJson(json);
    // Crunchy-shell validation
    final segments = result.key.split(',');
    final [senderId, idx] = segments;
    if (senderId != 'canned') {
      int.parse(senderId, radix: 10);
    }
    int.parse(idx, radix: 10);
    return result;
  }

  @override
  Map<String, Object?> toJson() => _$PollVoteEventSubmessageToJson(this);
}

/// As in [PollVoteEventSubmessage.op].
@JsonEnum(valueField: 'apiValue')
enum PollVoteOp {
  add(apiValue: 1),
  remove(apiValue: -1),
  unknown(apiValue: null);

  const PollVoteOp({required this.apiValue});

  final int? apiValue;

  int? toJson() => apiValue;
}

class UnknownPollEventSubmessage extends PollEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  PollEventSubmessageType get type => PollEventSubmessageType.unknown;

  final Map<String, Object?> json;

  UnknownPollEventSubmessage.fromJson(this.json);

  @override
  Map<String, Object?> toJson() => json;
}

/// States of a poll Zulip widget.
///
/// See also:
/// - https://zulip.com/help/create-a-poll
/// - https://github.com/zulip/zulip/blob/304d948416465c1a085122af5d752f03d6797003/web/shared/src/poll_data.ts
class Poll extends ChangeNotifier {
  /// Construct a poll from submessages.
  ///
  /// For a poll Zulip widget, the first submessage's content contains a
  /// [PollWidgetData], and all the following submessages' content each contains
  /// a [PollEventSubmessage].
  factory Poll.fromSubmessages({
    required PollWidgetData widgetData,
    required Iterable<Submessage> pollEventSubmessages,
    required int messageSenderId,
    required List<Submessage>? debugSubmessages,
  }) {
    final poll = Poll._(
      messageSenderId: messageSenderId,
      question: widgetData.extraData.question,
      options: widgetData.extraData.options,
      debugSubmessages: debugSubmessages,
    );

    for (final submessage in pollEventSubmessages) {
      final event = PollEventSubmessage.fromJson(jsonDecode(submessage.content) as Map<String, Object?>);
      poll._applyEvent(submessage.senderId, event);
    }
    return poll;
  }

  Poll._({
    required this.messageSenderId,
    required this.question,
    required List<String> options,
    required List<Submessage>? debugSubmessages,
  }) {
    for (int index = 0; index < options.length; index += 1) {
      // Initial poll options use a placeholder senderId.
      // See [PollEventSubmessage.optionKey] for details.
      _addOption(senderId: null, idx: index, option: options[index]);
    }
    if (kDebugMode) {
      _debugSubmessages = debugSubmessages;
    }
  }

  final int messageSenderId;
  String question;

  List<Submessage>? _debugSubmessages;

  /// The limit of options any single user can add to a poll.
  ///
  /// See https://github.com/zulip/zulip/blob/304d948416465c1a085122af5d752f03d6797003/web/shared/src/poll_data.ts#L69-L71
  static const _maxIdx = 1000;

  Iterable<PollOption> get options => _options.values;
  /// Contains the text of all options from [_options].
  final Set<String> _existingOptionTexts = {};
  final Map<PollOptionKey, PollOption> _options = {};

  void handleSubmessageEvent(SubmessageEvent event) {
    final PollEventSubmessage? pollEventSubmessage;
    try {
      pollEventSubmessage = PollEventSubmessage.fromJson(jsonDecode(event.content) as Map<String, Object?>);
    } catch (e) {
      assert(debugLog('Malformed submessage event data for poll: $e\n${jsonEncode(event)}')); // TODO(log)
      return;
    }
    _applyEvent(event.senderId, pollEventSubmessage);
    notifyListeners();

    if (kDebugMode) {
      assert(_debugSubmessages != null);
      _debugSubmessages!.add(Submessage(
        senderId: event.senderId,
        msgType: event.msgType,
        content: event.content));
    }
  }

  void _applyEvent(int senderId, PollEventSubmessage event) {
    switch (event) {
      case PollNewOptionEventSubmessage():
        _addOption(senderId: senderId, idx: event.idx, option: event.option);

      case PollQuestionEventSubmessage():
        if (senderId != messageSenderId) {
          // Only the message owner can edit the question.
          assert(debugLog('unexpected poll data: user $senderId is not allowed to edit the question')); // TODO(log)
          return;
        }

        question = event.question;

      case PollVoteEventSubmessage():
        final option = _options[event.key];
        if (option == null) {
          assert(debugLog('vote for unknown key ${event.key}')); // TODO(log)
          return;
        }

        switch (event.op) {
          case PollVoteOp.add:
            option.voters.add(senderId);
          case PollVoteOp.remove:
            option.voters.remove(senderId);
          case PollVoteOp.unknown:
            assert(debugLog('unknown vote op ${event.op}')); // TODO(log)
        }

      case UnknownPollEventSubmessage():
    }
  }

  void _addOption({required int? senderId, required int idx, required String option}) {
    if (idx > _maxIdx || idx < 0) return;

    // The web client suppresses duplicate options, which can be created through
    // the /poll command as there is no server-side validation.
    if (_existingOptionTexts.contains(option)) return;

    final key = PollEventSubmessage.optionKey(senderId: senderId, idx: idx);
    assert(!_options.containsKey(key));
    _options[key] = PollOption(key: key, text: option);
    _existingOptionTexts.add(option);
  }

  static Poll? fromJson(Object? json) {
    // [Submessage.parseSubmessagesJson] does all the heavy lifting for parsing.
    return json as Poll?;
  }

  static List<Submessage> toJson(Poll? poll) {
    List<Submessage>? result;

    if (kDebugMode) {
      // Useful for setting up a message list with a poll message, which goes
      // through this codepath (when preparing a fetch response).
      result = poll?._debugSubmessages;
    }

    // In prod, rather than maintaining a up-to-date submessages list,
    // return as if it is empty, because we are not sending the submessages
    // to the server anyway.
    return result ?? [];
  }
}

class PollOption {
  PollOption({required this.key, required this.text});

  final PollOptionKey key;
  final String text;
  final Set<int> voters = {};

  @override
  String toString() => 'PollOption(text: $text, voters: {${voters.join(', ')}})';
}

/// The data in a submessage that acts on a to-do list.
///
/// The first submessage on the message should be a [TodoWidgetData].
///
/// See: https://github.com/zulip/zulip/blob/40f59a05c/web/src/todo_data.ts
sealed class TodoEventSubmessage extends SubmessageData {
  TodoEventSubmessageType get type;

  TodoEventSubmessage();

  /// The key for identifying the [idx]'th task added by user [senderId]
  /// to a to-do list.
  ///
  /// For tasks that are a part of the initial [TodoWidgetData], the
  /// [senderId] should be `null`.
  ///
  /// Unlike [PollEventSubmessage.optionKey], the index comes first here;
  /// that's how the web client (todo_data.ts) builds this key.
  static TodoTaskKey taskKey({required int? senderId, required int idx}) =>
    '$idx,${senderId ?? 'canned'}';

  factory TodoEventSubmessage.fromJson(Map<String, Object?> json) {
    final rawTodoEventType = json['type'] as String;
    switch (TodoEventSubmessageType.fromRawString(rawTodoEventType)) {
      case TodoEventSubmessageType.newTaskListTitle: return TodoNewTaskListTitleEventSubmessage.fromJson(json);
      case TodoEventSubmessageType.newTask: return TodoNewTaskEventSubmessage.fromJson(json);
      case TodoEventSubmessageType.strike: return TodoStrikeEventSubmessage.fromJson(json);
      case TodoEventSubmessageType.editTask: return TodoEditTaskEventSubmessage.fromJson(json);
      case TodoEventSubmessageType.startTask: return TodoStartTaskEventSubmessage.fromJson(json);
      case TodoEventSubmessageType.resetTask: return TodoResetTaskEventSubmessage.fromJson(json);
      case TodoEventSubmessageType.unknown: return UnknownTodoEventSubmessage.fromJson(json);
    }
  }

  @override
  Map<String, Object?> toJson();
}

/// As in [TodoEventSubmessage.type].
@JsonEnum(fieldRename: FieldRename.snake)
enum TodoEventSubmessageType {
  newTaskListTitle,
  newTask,
  strike,
  // The following are local server additions, not in upstream Zulip.
  editTask,
  startTask,
  resetTask,
  unknown;

  static TodoEventSubmessageType fromRawString(String raw) => _byRawString[raw] ?? unknown;

  static final _byRawString = _$TodoEventSubmessageTypeEnumMap
    .map((key, value) => MapEntry(value, key));
}

typedef TodoTaskKey = String;

/// A to-do list event when the task list's title has been edited.
///
/// Only the message's sender may do this.
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoNewTaskListTitleEventSubmessage extends TodoEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  TodoEventSubmessageType get type => TodoEventSubmessageType.newTaskListTitle;

  final String title;

  TodoNewTaskListTitleEventSubmessage({required this.title});

  factory TodoNewTaskListTitleEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$TodoNewTaskListTitleEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$TodoNewTaskListTitleEventSubmessageToJson(this);
}

/// A to-do list event when a task is added.
///
/// See: https://github.com/zulip/zulip/blob/40f59a05c/web/src/todo_data.ts#L116-L170
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoNewTaskEventSubmessage extends TodoEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  TodoEventSubmessageType get type => TodoEventSubmessageType.newTask;

  /// A sequence number for this task, among tasks added to this to-do list
  /// by this [Submessage.senderId].
  ///
  /// Confusingly named "key" in the wire format, but it's really an index;
  /// see [TodoEventSubmessage.taskKey].
  final int key;
  final String task;
  final String desc;
  /// As in [TodoTaskData.deadline].
  @JsonKey(defaultValue: '')
  final String deadline;
  final bool completed;

  TodoNewTaskEventSubmessage({
    required this.key,
    required this.task,
    required this.desc,
    required this.deadline,
    required this.completed,
  });

  factory TodoNewTaskEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$TodoNewTaskEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$TodoNewTaskEventSubmessageToJson(this);
}

/// A to-do list event when a task is marked done/not-done.
///
/// See: https://github.com/zulip/zulip/blob/40f59a05c/web/src/todo_data.ts#L172-L206
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoStrikeEventSubmessage extends TodoEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  TodoEventSubmessageType get type => TodoEventSubmessageType.strike;

  /// The key of the affected task.
  ///
  /// See [TodoEventSubmessage.taskKey].
  final TodoTaskKey key;

  TodoStrikeEventSubmessage({required this.key});

  factory TodoStrikeEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$TodoStrikeEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$TodoStrikeEventSubmessageToJson(this);
}

/// A to-do list event when the list's author edits a task's
/// description and deadline.
///
/// A local server addition, not in upstream Zulip.
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoEditTaskEventSubmessage extends TodoEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  TodoEventSubmessageType get type => TodoEventSubmessageType.editTask;

  final TodoTaskKey key;
  final String desc;
  /// As in [TodoTaskData.deadline].
  final String deadline;

  TodoEditTaskEventSubmessage({required this.key, required this.desc, required this.deadline});

  factory TodoEditTaskEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$TodoEditTaskEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$TodoEditTaskEventSubmessageToJson(this);
}

/// A to-do list event when the assignee starts a task.
///
/// In a list with an assignee, a task must be started
/// before it can be checked off.
///
/// A local server addition, not in upstream Zulip.
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoStartTaskEventSubmessage extends TodoEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  TodoEventSubmessageType get type => TodoEventSubmessageType.startTask;

  final TodoTaskKey key;

  TodoStartTaskEventSubmessage({required this.key});

  factory TodoStartTaskEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$TodoStartTaskEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$TodoStartTaskEventSubmessageToJson(this);
}

/// A to-do list event when the list's author takes a task back to pending.
///
/// A local server addition, not in upstream Zulip.
@JsonSerializable(fieldRename: FieldRename.snake)
class TodoResetTaskEventSubmessage extends TodoEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  TodoEventSubmessageType get type => TodoEventSubmessageType.resetTask;

  final TodoTaskKey key;

  TodoResetTaskEventSubmessage({required this.key});

  factory TodoResetTaskEventSubmessage.fromJson(Map<String, Object?> json) =>
    _$TodoResetTaskEventSubmessageFromJson(json);

  @override
  Map<String, Object?> toJson() => _$TodoResetTaskEventSubmessageToJson(this);
}

class UnknownTodoEventSubmessage extends TodoEventSubmessage {
  @override
  @JsonKey(includeToJson: true)
  TodoEventSubmessageType get type => TodoEventSubmessageType.unknown;

  final Map<String, Object?> json;

  UnknownTodoEventSubmessage.fromJson(this.json);

  @override
  Map<String, Object?> toJson() => json;
}

/// States of a to-do list Zulip widget.
///
/// See also:
/// - https://zulip.com/help/collaborative-to-do-lists
/// - https://github.com/zulip/zulip/blob/40f59a05c/web/src/todo_data.ts
class TodoList extends ChangeNotifier {
  /// Construct a to-do list from submessages.
  ///
  /// For a to-do list Zulip widget, the first submessage's content contains
  /// a [TodoWidgetData], and all the following submessages' content each
  /// contains a [TodoEventSubmessage].
  factory TodoList.fromSubmessages({
    required TodoWidgetData widgetData,
    required Iterable<Submessage> todoEventSubmessages,
    required int messageSenderId,
    required List<Submessage>? debugSubmessages,
  }) {
    final todoList = TodoList._(
      messageSenderId: messageSenderId,
      taskListTitle: widgetData.extraData.taskListTitle,
      assignee: widgetData.extraData.assignee,
      debugSubmessages: debugSubmessages,
    );

    final initialTasks = widgetData.extraData.tasks;
    for (int index = 0; index < initialTasks.length; index += 1) {
      // Initial tasks use a placeholder senderId, same idea as poll options.
      todoList._addTask(senderId: null, idx: index,
        task: initialTasks[index].task, desc: initialTasks[index].desc,
        deadline: initialTasks[index].deadline, completed: false);
    }

    for (final submessage in todoEventSubmessages) {
      final event = TodoEventSubmessage.fromJson(jsonDecode(submessage.content) as Map<String, Object?>);
      todoList._applyEvent(submessage.senderId, event);
    }
    return todoList;
  }

  TodoList._({
    required this.messageSenderId,
    required this.taskListTitle,
    required this.assignee,
    required List<Submessage>? debugSubmessages,
  }) {
    if (kDebugMode) {
      _debugSubmessages = debugSubmessages;
    }
  }

  final int messageSenderId;
  String taskListTitle;

  /// As in [TodoWidgetExtraData.assignee].
  ///
  /// A list with an assignee follows extra rules:
  /// only the assignee can start a task, a task must be started
  /// before it can be checked off, and only the author can uncheck a task
  /// or take it back to pending.
  final TodoAssignee? assignee;

  /// Whether the given user is barred from unchecking a completed task.
  bool isUncheckRestricted(int userId) =>
    assignee != null && userId != messageSenderId;

  List<Submessage>? _debugSubmessages;

  /// The limit of tasks any single user can add to a to-do list.
  ///
  /// See [Poll._maxIdx]; the to-do list widget follows the same convention.
  static const _maxIdx = 1000;

  Iterable<TodoTask> get tasks => _tasks.values;
  /// Contains the text of all tasks from [_tasks].
  final Set<String> _existingTaskTexts = {};
  final Map<TodoTaskKey, TodoTask> _tasks = {};

  void handleSubmessageEvent(SubmessageEvent event) {
    final TodoEventSubmessage? todoEventSubmessage;
    try {
      todoEventSubmessage = TodoEventSubmessage.fromJson(jsonDecode(event.content) as Map<String, Object?>);
    } catch (e) {
      assert(debugLog('Malformed submessage event data for to-do list: $e\n${jsonEncode(event)}')); // TODO(log)
      return;
    }
    _applyEvent(event.senderId, todoEventSubmessage);
    notifyListeners();

    if (kDebugMode) {
      assert(_debugSubmessages != null);
      _debugSubmessages!.add(Submessage(
        senderId: event.senderId,
        msgType: event.msgType,
        content: event.content));
    }
  }

  void _applyEvent(int senderId, TodoEventSubmessage event) {
    switch (event) {
      case TodoNewTaskListTitleEventSubmessage():
        if (senderId != messageSenderId) {
          // Only the message owner can edit the task list title.
          assert(debugLog('unexpected to-do list data: user $senderId is not allowed to edit the title')); // TODO(log)
          return;
        }

        taskListTitle = event.title;

      case TodoNewTaskEventSubmessage():
        _addTask(senderId: senderId, idx: event.key,
          task: event.task, desc: event.desc, deadline: event.deadline,
          completed: event.completed);

      case TodoStrikeEventSubmessage():
        final task = _tasks[event.key];
        if (task == null) {
          assert(debugLog('strike for unknown to-do task key ${event.key}')); // TODO(log)
          return;
        }
        if (task.completed && isUncheckRestricted(senderId)) return;

        task.completed = !task.completed;

      case TodoEditTaskEventSubmessage():
        if (senderId != messageSenderId) {
          assert(debugLog('unexpected to-do list data: user $senderId is not allowed to edit tasks')); // TODO(log)
          return;
        }
        final task = _tasks[event.key];
        if (task == null) return;
        task.desc = event.desc;
        task.deadline = event.deadline;

      case TodoStartTaskEventSubmessage():
        if (senderId != assignee?.userId) {
          assert(debugLog('unexpected to-do list data: user $senderId is not allowed to start tasks')); // TODO(log)
          return;
        }
        final task = _tasks[event.key];
        if (task != null && !task.completed) task.inProgress = true;

      case TodoResetTaskEventSubmessage():
        if (senderId != messageSenderId) {
          assert(debugLog('unexpected to-do list data: user $senderId is not allowed to reset tasks')); // TODO(log)
          return;
        }
        final task = _tasks[event.key];
        if (task == null) return;
        task.completed = false;
        task.inProgress = false;

      case UnknownTodoEventSubmessage():
    }
  }

  void _addTask({
    required int? senderId,
    required int idx,
    required String task,
    required String desc,
    required String deadline,
    required bool completed,
  }) {
    if (idx > _maxIdx || idx < 0) return;

    // Suppress duplicate tasks, same as the web client does for polls
    // (and for to-do lists: see todo_data.ts's `name_in_use`).
    if (_existingTaskTexts.contains(task)) return;

    final key = TodoEventSubmessage.taskKey(senderId: senderId, idx: idx);
    if (_tasks.containsKey(key)) return;
    _tasks[key] = TodoTask(key: key, task: task, desc: desc, deadline: deadline,
      completed: completed, inProgress: false);
    _existingTaskTexts.add(task);
  }

  static TodoList? fromJson(Object? json) {
    // [Submessage.parseSubmessagesJson] does all the heavy lifting for parsing.
    return json as TodoList?;
  }

  static List<Submessage> toJson(TodoList? todoList) {
    List<Submessage>? result;

    if (kDebugMode) {
      result = todoList?._debugSubmessages;
    }

    // In prod, rather than maintaining an up-to-date submessages list,
    // return as if it is empty, because we are not sending the submessages
    // to the server anyway.
    return result ?? [];
  }
}

class TodoTask {
  TodoTask({
    required this.key,
    required this.task,
    required this.desc,
    required this.deadline,
    required this.completed,
    required this.inProgress,
  });

  final TodoTaskKey key;
  final String task;
  String desc;
  /// As in [TodoTaskData.deadline].
  String deadline;
  bool completed;
  /// Whether the assignee has started this task; see [TodoList.assignee].
  bool inProgress;

  /// Whether the deadline has passed, as of [now].
  ///
  /// Like the web client, this reads the deadline date as midnight UTC.
  bool isOverdue(DateTime now) {
    if (deadline.isEmpty) return false;
    final date = DateTime.tryParse(deadline);
    if (date == null) return false;
    return DateTime.utc(date.year, date.month, date.day).isBefore(now);
  }

  @override
  String toString() => 'TodoTask(task: $task, completed: $completed, inProgress: $inProgress)';
}
