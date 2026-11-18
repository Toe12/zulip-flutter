// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: constant_identifier_names, unnecessary_cast

part of 'submessage.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Submessage _$SubmessageFromJson(Map<String, dynamic> json) => Submessage(
  senderId: (json['sender_id'] as num).toInt(),
  msgType: $enumDecode(
    _$SubmessageTypeEnumMap,
    json['msg_type'],
    unknownValue: SubmessageType.unknown,
  ),
  content: json['content'] as String,
);

Map<String, dynamic> _$SubmessageToJson(Submessage instance) =>
    <String, dynamic>{
      'sender_id': instance.senderId,
      'msg_type': instance.msgType,
      'content': instance.content,
    };

const _$SubmessageTypeEnumMap = {
  SubmessageType.widget: 'widget',
  SubmessageType.unknown: 'unknown',
};

PollWidgetData _$PollWidgetDataFromJson(Map<String, dynamic> json) =>
    PollWidgetData(
      extraData: PollWidgetExtraData.fromJson(
        json['extra_data'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$PollWidgetDataToJson(PollWidgetData instance) =>
    <String, dynamic>{
      'widget_type': _$WidgetTypeEnumMap[instance.widgetType]!,
      'extra_data': instance.extraData,
    };

const _$WidgetTypeEnumMap = {
  WidgetType.poll: 'poll',
  WidgetType.todo: 'todo',
  WidgetType.unknown: 'unknown',
};

PollWidgetExtraData _$PollWidgetExtraDataFromJson(Map<String, dynamic> json) =>
    PollWidgetExtraData(
      question: json['question'] as String? ?? '',
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );

Map<String, dynamic> _$PollWidgetExtraDataToJson(
  PollWidgetExtraData instance,
) => <String, dynamic>{
  'question': instance.question,
  'options': instance.options,
};

TodoWidgetData _$TodoWidgetDataFromJson(Map<String, dynamic> json) =>
    TodoWidgetData(
      extraData: TodoWidgetExtraData.fromJson(
        json['extra_data'] as Map<String, dynamic>,
      ),
    );

Map<String, dynamic> _$TodoWidgetDataToJson(TodoWidgetData instance) =>
    <String, dynamic>{
      'widget_type': _$WidgetTypeEnumMap[instance.widgetType]!,
      'extra_data': instance.extraData,
    };

TodoWidgetExtraData _$TodoWidgetExtraDataFromJson(Map<String, dynamic> json) =>
    TodoWidgetExtraData(
      taskListTitle: json['task_list_title'] as String? ?? '',
      tasks:
          (json['tasks'] as List<dynamic>?)
              ?.map((e) => TodoTaskData.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      assignee: json['assignee'] == null
          ? null
          : TodoAssignee.fromJson(json['assignee'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$TodoWidgetExtraDataToJson(
  TodoWidgetExtraData instance,
) => <String, dynamic>{
  'task_list_title': instance.taskListTitle,
  'tasks': instance.tasks,
  'assignee': instance.assignee,
};

TodoTaskData _$TodoTaskDataFromJson(Map<String, dynamic> json) => TodoTaskData(
  task: json['task'] as String,
  desc: json['desc'] as String,
  deadline: json['deadline'] as String? ?? '',
);

Map<String, dynamic> _$TodoTaskDataToJson(TodoTaskData instance) =>
    <String, dynamic>{
      'task': instance.task,
      'desc': instance.desc,
      'deadline': instance.deadline,
    };

TodoAssignee _$TodoAssigneeFromJson(Map<String, dynamic> json) => TodoAssignee(
  userId: (json['user_id'] as num).toInt(),
  email: json['email'] as String,
);

Map<String, dynamic> _$TodoAssigneeToJson(TodoAssignee instance) =>
    <String, dynamic>{'user_id': instance.userId, 'email': instance.email};

PollNewOptionEventSubmessage _$PollNewOptionEventSubmessageFromJson(
  Map<String, dynamic> json,
) => PollNewOptionEventSubmessage(
  option: json['option'] as String,
  idx: (json['idx'] as num).toInt(),
);

Map<String, dynamic> _$PollNewOptionEventSubmessageToJson(
  PollNewOptionEventSubmessage instance,
) => <String, dynamic>{
  'type': _$PollEventSubmessageTypeEnumMap[instance.type]!,
  'option': instance.option,
  'idx': instance.idx,
};

const _$PollEventSubmessageTypeEnumMap = {
  PollEventSubmessageType.newOption: 'new_option',
  PollEventSubmessageType.question: 'question',
  PollEventSubmessageType.vote: 'vote',
  PollEventSubmessageType.unknown: 'unknown',
};

PollQuestionEventSubmessage _$PollQuestionEventSubmessageFromJson(
  Map<String, dynamic> json,
) => PollQuestionEventSubmessage(question: json['question'] as String);

Map<String, dynamic> _$PollQuestionEventSubmessageToJson(
  PollQuestionEventSubmessage instance,
) => <String, dynamic>{
  'type': _$PollEventSubmessageTypeEnumMap[instance.type]!,
  'question': instance.question,
};

PollVoteEventSubmessage _$PollVoteEventSubmessageFromJson(
  Map<String, dynamic> json,
) => PollVoteEventSubmessage(
  key: json['key'] as PollOptionKey,
  op:
      $enumDecodeNullable(
        _$PollVoteOpEnumMap,
        json['vote'],
        unknownValue: PollVoteOp.unknown,
      ) ??
      PollVoteOp.unknown,
);

Map<String, dynamic> _$PollVoteEventSubmessageToJson(
  PollVoteEventSubmessage instance,
) => <String, dynamic>{
  'type': _$PollEventSubmessageTypeEnumMap[instance.type]!,
  'key': instance.key,
  'vote': instance.op,
};

const _$PollVoteOpEnumMap = {
  PollVoteOp.add: 1,
  PollVoteOp.remove: -1,
  PollVoteOp.unknown: null,
};

TodoNewTaskListTitleEventSubmessage
_$TodoNewTaskListTitleEventSubmessageFromJson(Map<String, dynamic> json) =>
    TodoNewTaskListTitleEventSubmessage(title: json['title'] as String);

Map<String, dynamic> _$TodoNewTaskListTitleEventSubmessageToJson(
  TodoNewTaskListTitleEventSubmessage instance,
) => <String, dynamic>{
  'type': _$TodoEventSubmessageTypeEnumMap[instance.type]!,
  'title': instance.title,
};

const _$TodoEventSubmessageTypeEnumMap = {
  TodoEventSubmessageType.newTaskListTitle: 'new_task_list_title',
  TodoEventSubmessageType.newTask: 'new_task',
  TodoEventSubmessageType.strike: 'strike',
  TodoEventSubmessageType.editTask: 'edit_task',
  TodoEventSubmessageType.startTask: 'start_task',
  TodoEventSubmessageType.resetTask: 'reset_task',
  TodoEventSubmessageType.unknown: 'unknown',
};

TodoNewTaskEventSubmessage _$TodoNewTaskEventSubmessageFromJson(
  Map<String, dynamic> json,
) => TodoNewTaskEventSubmessage(
  key: (json['key'] as num).toInt(),
  task: json['task'] as String,
  desc: json['desc'] as String,
  deadline: json['deadline'] as String? ?? '',
  completed: json['completed'] as bool,
);

Map<String, dynamic> _$TodoNewTaskEventSubmessageToJson(
  TodoNewTaskEventSubmessage instance,
) => <String, dynamic>{
  'type': _$TodoEventSubmessageTypeEnumMap[instance.type]!,
  'key': instance.key,
  'task': instance.task,
  'desc': instance.desc,
  'deadline': instance.deadline,
  'completed': instance.completed,
};

TodoStrikeEventSubmessage _$TodoStrikeEventSubmessageFromJson(
  Map<String, dynamic> json,
) => TodoStrikeEventSubmessage(key: json['key'] as TodoTaskKey);

Map<String, dynamic> _$TodoStrikeEventSubmessageToJson(
  TodoStrikeEventSubmessage instance,
) => <String, dynamic>{
  'type': _$TodoEventSubmessageTypeEnumMap[instance.type]!,
  'key': instance.key,
};

TodoEditTaskEventSubmessage _$TodoEditTaskEventSubmessageFromJson(
  Map<String, dynamic> json,
) => TodoEditTaskEventSubmessage(
  key: json['key'] as TodoTaskKey,
  desc: json['desc'] as String,
  deadline: json['deadline'] as String,
);

Map<String, dynamic> _$TodoEditTaskEventSubmessageToJson(
  TodoEditTaskEventSubmessage instance,
) => <String, dynamic>{
  'type': _$TodoEventSubmessageTypeEnumMap[instance.type]!,
  'key': instance.key,
  'desc': instance.desc,
  'deadline': instance.deadline,
};

TodoStartTaskEventSubmessage _$TodoStartTaskEventSubmessageFromJson(
  Map<String, dynamic> json,
) => TodoStartTaskEventSubmessage(key: json['key'] as TodoTaskKey);

Map<String, dynamic> _$TodoStartTaskEventSubmessageToJson(
  TodoStartTaskEventSubmessage instance,
) => <String, dynamic>{
  'type': _$TodoEventSubmessageTypeEnumMap[instance.type]!,
  'key': instance.key,
};

TodoResetTaskEventSubmessage _$TodoResetTaskEventSubmessageFromJson(
  Map<String, dynamic> json,
) => TodoResetTaskEventSubmessage(key: json['key'] as TodoTaskKey);

Map<String, dynamic> _$TodoResetTaskEventSubmessageToJson(
  TodoResetTaskEventSubmessage instance,
) => <String, dynamic>{
  'type': _$TodoEventSubmessageTypeEnumMap[instance.type]!,
  'key': instance.key,
};
