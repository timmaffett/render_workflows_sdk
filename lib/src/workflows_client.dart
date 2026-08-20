import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:render_api/render_api.dart';

import 'pagination.dart';
import 'status.dart';
import 'task_run.dart';

/// Starts, watches and cancels Render Workflows task runs.
///
/// The method names mirror Render's official TypeScript SDK exactly —
/// `startTask`, `runTask`, `getTaskRun`, `cancelTaskRun`, `listTaskRuns`,
/// `taskRunEvents` — so its documentation and examples carry over. A few
/// additions ([waitFor], [listTaskRunsStream]) exist where Dart offers
/// something the TypeScript surface has no equivalent for.
///
/// Workflow *services* — creating them, deploying versions, listing task
/// definitions — are plain REST and live in `package:render_api`. Render draws
/// the same line: its workflows SDK runs tasks and nothing else.
class WorkflowsClient {
  const WorkflowsClient(this._client);

  final RenderApiClient _client;

  /// Render rejects an invocation whose arguments exceed 4 MB.
  static const int maxInputBytes = 4 * 1024 * 1024;

  /// Starts a run of [taskSlug] and returns immediately.
  ///
  /// [taskSlug] is `workflow-slug/task-name`, optionally pinned to a version
  /// with `workflow-slug/task-name:version`. [inputData] holds the task's
  /// positional arguments; a task taking none gets an empty list.
  ///
  /// The 4 MB input cap is checked here rather than left to the API, so an
  /// oversized payload fails by name instead of arriving as a generic
  /// rejection.
  Future<TaskRun> startTask(String taskSlug, List<Object?> inputData) async {
    _assertInputWithinLimit(taskSlug, inputData);
    final json = await _client.sendObject(
      'POST',
      '/task-runs',
      body: {'task': taskSlug, 'input': inputData},
    );
    return TaskRun.fromJson(json);
  }

  /// Starts a run and waits for it to finish.
  ///
  /// Polls rather than streaming, so it works on every platform including
  /// Flutter Web — see [taskRunEvents] for the push-based alternative and its
  /// caveat there.
  ///
  /// Does not throw when the run fails; inspect [TaskRunDetails.error].
  Future<TaskRunDetails> runTask(
    String taskSlug,
    List<Object?> inputData, {
    Duration pollInterval = const Duration(milliseconds: 500),
    Duration? timeout,
  }) async {
    final started = await startTask(taskSlug, inputData);
    return waitFor(started.id, pollInterval: pollInterval, timeout: timeout);
  }

  /// Retrieves a run, including its input, results and error.
  Future<TaskRunDetails> getTaskRun(String taskRunId) async {
    final json = await _client.sendObject('GET', '/task-runs/$taskRunId');
    return TaskRunDetails.fromJson(json);
  }

  /// Cancels a run that has not finished. Throws if it is already terminal.
  Future<void> cancelTaskRun(String taskRunId) =>
      _client.send('DELETE', '/task-runs/$taskRunId');

  /// Lists one page of runs matching the given filters.
  Future<Page<TaskRun>> listTaskRuns({
    String? cursor,
    int limit = 20,
    List<String>? taskSlugs,
    List<String>? rootTaskRunIds,
    List<String>? ownerIds,
    List<String>? workflowIds,
    List<String>? workflowVersionIds,
  }) async {
    final json = await _client.sendList(
      'GET',
      '/task-runs',
      query: {
        if (cursor != null) 'cursor': cursor,
        'limit': limit,
        'taskSlug': taskSlugs,
        'rootTaskRunId': rootTaskRunIds,
        'ownerId': ownerIds,
        'workflowId': workflowIds,
        'workflowVersionId': workflowVersionIds,
      },
    );
    return Page.fromJson(json, 'taskRun', TaskRun.fromJson);
  }

  /// Lists runs across every page, walking cursors for you.
  Stream<TaskRun> listTaskRunsStream({
    int pageSize = 20,
    int? max,
    List<String>? taskSlugs,
    List<String>? rootTaskRunIds,
    List<String>? ownerIds,
    List<String>? workflowIds,
    List<String>? workflowVersionIds,
  }) => paginate(
    (cursor, limit) => listTaskRuns(
      cursor: cursor,
      limit: limit,
      taskSlugs: taskSlugs,
      rootTaskRunIds: rootTaskRunIds,
      ownerIds: ownerIds,
      workflowIds: workflowIds,
      workflowVersionIds: workflowVersionIds,
    ),
    limit: pageSize,
    max: max,
  );

  /// Polls [taskRunId] until it reaches a terminal state.
  ///
  /// Does not throw when the run fails — inspect [TaskRunDetails.error]. It
  /// throws only if [timeout] elapses first.
  Future<TaskRunDetails> waitFor(
    String taskRunId, {
    Duration pollInterval = const Duration(milliseconds: 500),
    Duration? timeout,
  }) async {
    final deadline = timeout == null ? null : DateTime.now().add(timeout);

    while (true) {
      final details = await getTaskRun(taskRunId);
      if (details.isTerminal) return details;

      if (deadline != null && DateTime.now().isAfter(deadline)) {
        throw TimeoutException(
          'Task run $taskRunId did not finish within ${timeout!.inSeconds}s '
          '(last status: ${details.status.name}).',
        );
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  /// Streams runs as they reach a terminal state, over server-sent events.
  ///
  /// **Not usable on Flutter Web with the default HTTP client.**
  /// `package:http`'s `BrowserClient` is backed by `XMLHttpRequest` and
  /// buffers whole responses, so this yields nothing until the connection
  /// closes. On the web either inject a streaming-capable client
  /// (`package:fetch_client`) or use [waitFor], which polls.
  Stream<TaskRunDetails> taskRunEvents(
    List<String> taskRunIds, {
    http.Client? httpClient,
  }) async* {
    if (taskRunIds.isEmpty) return;

    final client = httpClient ?? http.Client();
    final query = taskRunIds.map((id) => 'taskRunIds=$id').join('&');
    final request = http.Request(
      'GET',
      Uri.parse('${_client.baseUrl}/task-runs/events?$query'),
    )..headers.addAll(_client.authHeaders(accept: 'text/event-stream'));

    try {
      final response = await client.send(request);
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      final data = StringBuffer();
      await for (final line in lines) {
        if (line.isEmpty) {
          // A blank line terminates an SSE frame.
          final payload = data.toString();
          data.clear();
          if (payload.isEmpty) continue;
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, Object?>) {
            yield TaskRunDetails.fromJson(decoded);
          }
        } else if (line.startsWith('data:')) {
          data.write(line.substring(5).trimLeft());
        }
        // `id:`, `event:` and `retry:` carry nothing this client needs.
      }
    } finally {
      if (httpClient == null) client.close();
    }
  }

  static void _assertInputWithinLimit(String taskSlug, List<Object?> input) {
    final encoded = utf8.encode(jsonEncode(input)).length;
    if (encoded > maxInputBytes) {
      throw ArgumentError.value(
        input,
        'inputData',
        'Input for "$taskSlug" is ${(encoded / 1048576).toStringAsFixed(2)} MB, '
            'over Render\'s 4 MB per-invocation limit. Pass a reference '
            '(an object key, a row id) instead of the payload itself.',
      );
    }
  }
}

/// Convenience predicates over a batch of runs.
extension TaskRunListX on Iterable<TaskRun> {
  bool get allTerminal => every((r) => r.isTerminal);
  Iterable<TaskRun> get failed =>
      where((r) => r.status == TaskRunStatus.failed);
  Iterable<TaskRun> get children => where((r) => r.isChildRun);
}
