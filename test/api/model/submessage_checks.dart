
import 'package:checks/checks.dart';
import 'package:zulip/api/model/submessage.dart';

extension SubmessageChecks on Subject<Submessage> {
  Subject<int> get senderId => has((e) => e.senderId, 'senderId');
  Subject<SubmessageType> get msgType => has((e) => e.msgType, 'msgType');
  Subject<Object?> get content => has((e) => e.content, 'content');
}

extension WidgetDataChecks on Subject<WidgetData> {
  Subject<WidgetType> get widgetType => has((e) => e.widgetType, 'widgetType');
}

extension PollWidgetDataChecks on Subject<PollWidgetData> {
  Subject<PollWidgetExtraData> get extraData => has((e) => e.extraData, 'extraData');
}

extension PollWidgetExtraDataChecks on Subject<PollWidgetExtraData> {
  Subject<String> get question => has((e) => e.question, 'question');
  Subject<List<String>> get options => has((e) => e.options, 'options');
}

extension PollEventChecks on Subject<PollEventSubmessage> {
  Subject<PollEventSubmessageType> get type => has((e) => e.type, 'type');
}

extension PollOptionEventChecks on Subject<PollNewOptionEventSubmessage> {
  Subject<String> get option => has((e) => e.option, 'option');
}

extension PollQuestionEventChecks on Subject<PollQuestionEventSubmessage> {
  Subject<String> get question => has((e) => e.question, 'question');
}

extension PollVoteEventChecks on Subject<PollVoteEventSubmessage> {
  Subject<String> get key => has((e) => e.key, 'key');
  Subject<PollVoteOp> get op => has((e) => e.op, 'op');
}

extension PollChecks on Subject<Poll> {
  Subject<String> get question => has((e) => e.question, 'question');
  Subject<Iterable<PollOption>> get options => has((e) => e.options, 'options');
}

extension PollOptionChecks on Subject<PollOption> {
  Subject<String> get text => has((e) => e.text, 'text');
  Subject<Set<int>> get voters => has((e) => e.voters, 'voters');
}

extension TodoListChecks on Subject<TodoList> {
  Subject<String> get taskListTitle => has((e) => e.taskListTitle, 'taskListTitle');
  Subject<TodoAssignee?> get assignee => has((e) => e.assignee, 'assignee');
  Subject<Iterable<TodoTask>> get tasks => has((e) => e.tasks, 'tasks');
}

extension TodoTaskChecks on Subject<TodoTask> {
  Subject<String> get task => has((e) => e.task, 'task');
  Subject<String> get desc => has((e) => e.desc, 'desc');
  Subject<String> get deadline => has((e) => e.deadline, 'deadline');
  Subject<bool> get completed => has((e) => e.completed, 'completed');
  Subject<bool> get inProgress => has((e) => e.inProgress, 'inProgress');
}

extension TodoAssigneeChecks on Subject<TodoAssignee> {
  Subject<int> get userId => has((e) => e.userId, 'userId');
}
