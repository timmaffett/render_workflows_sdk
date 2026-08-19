import 'status.dart';

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v as String);

/// One attempt at executing a task run. A run has more than one attempt when
/// Render retries it.
class TaskRunAttempt {
  const TaskRunAttempt({
    required this.attempt,
    required this.status,
    required this.rawStatus,
    this.taskRunId,
    this.enqueuedAt,
    this.startedAt,
    this.completedAt,
    this.error,
    this.results,
  });

  factory TaskRunAttempt.fromJson(Map<String, Object?> json) => TaskRunAttempt(
        attempt: (json['attempt'] as num?)?.toInt() ?? 0,
        status: TaskRunStatus.fromWire(json['status'] as String?),
        rawStatus: json['status'] as String? ?? '',
        taskRunId: json['taskRunId'] as String?,
        enqueuedAt: _date(json['enqueuedAt']),
        startedAt: _date(json['startedAt']),
        completedAt: _date(json['completedAt']),
        error: json['error'] as String?,
        results: json['results'] as List<Object?>?,
      );

  /// Zero-indexed attempt number.
  final int attempt;
  final TaskRunStatus status;

  /// The status exactly as Render sent it, in case [status] is
  /// [TaskRunStatus.unknown].
  final String rawStatus;

  final String? taskRunId;
  final DateTime? enqueuedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? error;
  final List<Object?>? results;

  Duration? get duration => (startedAt == null || completedAt == null)
      ? null
      : completedAt!.difference(startedAt!);
}

/// A single execution of a workflow task, as returned by list endpoints.
///
/// [TaskRunDetails] carries the input, results and error as well.
class TaskRun {
  const TaskRun({
    required this.id,
    required this.taskId,
    required this.status,
    required this.rawStatus,
    required this.retries,
    required this.attempts,
    this.parentTaskRunId,
    this.parentTaskAttempt,
    this.rootTaskRunId,
    this.startedAt,
    this.completedAt,
  });

  factory TaskRun.fromJson(Map<String, Object?> json) => TaskRun(
        id: json['id'] as String? ?? '',
        taskId: json['taskId'] as String? ?? '',
        status: TaskRunStatus.fromWire(json['status'] as String?),
        rawStatus: json['status'] as String? ?? '',
        retries: (json['retries'] as num?)?.toInt() ?? 0,
        attempts: (json['attempts'] as List<Object?>? ?? const [])
            .whereType<Map<String, Object?>>()
            .map(TaskRunAttempt.fromJson)
            .toList(growable: false),
        parentTaskRunId: _blankToNull(json['parentTaskRunId'] as String?),
        parentTaskAttempt: (json['parentTaskAttempt'] as num?)?.toInt(),
        rootTaskRunId: _blankToNull(json['rootTaskRunId'] as String?),
        startedAt: _date(json['startedAt']),
        completedAt: _date(json['completedAt']),
      );

  final String id;
  final String taskId;
  final TaskRunStatus status;

  /// The status exactly as Render sent it.
  final String rawStatus;

  final int retries;
  final List<TaskRunAttempt> attempts;

  /// The run that spawned this one, if it is a child run.
  final String? parentTaskRunId;

  /// The zero-indexed attempt of the parent that spawned this run. Absent for
  /// root runs and for runs created before Render added the field.
  final int? parentTaskAttempt;

  /// The run at the top of this run's tree.
  final String? rootTaskRunId;

  final DateTime? startedAt;
  final DateTime? completedAt;

  bool get isTerminal => status.isTerminal;
  bool get isChildRun => parentTaskRunId != null;

  Duration? get duration => (startedAt == null || completedAt == null)
      ? null
      : completedAt!.difference(startedAt!);

  @override
  String toString() => 'TaskRun($id, ${status.name})';
}

/// A task run with its input, results and error.
class TaskRunDetails extends TaskRun {
  const TaskRunDetails({
    required super.id,
    required super.taskId,
    required super.status,
    required super.rawStatus,
    required super.retries,
    required super.attempts,
    required this.results,
    required this.input,
    this.error,
    super.parentTaskRunId,
    super.parentTaskAttempt,
    super.rootTaskRunId,
    super.startedAt,
    super.completedAt,
  });

  factory TaskRunDetails.fromJson(Map<String, Object?> json) {
    final base = TaskRun.fromJson(json);
    return TaskRunDetails(
      id: base.id,
      taskId: base.taskId,
      status: base.status,
      rawStatus: base.rawStatus,
      retries: base.retries,
      attempts: base.attempts,
      parentTaskRunId: base.parentTaskRunId,
      parentTaskAttempt: base.parentTaskAttempt,
      rootTaskRunId: base.rootTaskRunId,
      startedAt: base.startedAt,
      completedAt: base.completedAt,
      results: json['results'] as List<Object?>? ?? const [],
      input: json['input'],
      error: json['error'] as String?,
    );
  }

  /// Values the task returned. Render wraps a task's single return value in a
  /// list; [result] unwraps it.
  final List<Object?> results;

  /// The arguments the run was started with — a positional list, or an object.
  final Object? input;

  /// The failure message, when the run failed.
  final String? error;

  /// The task's return value, or null if it returned nothing.
  Object? get result => results.isEmpty ? null : results.first;

  @override
  String toString() => 'TaskRunDetails($id, ${status.name}'
      '${error == null ? '' : ', error: $error'})';
}

String? _blankToNull(String? v) => (v == null || v.isEmpty) ? null : v;
