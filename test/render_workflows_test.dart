import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:render_workflows/render_workflows.dart';
import 'package:test/test.dart';

Render renderWith(Future<http.Response> Function(http.Request) handler) =>
    Render(token: 'test-token', httpClient: MockClient(handler));

http.Response json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Map<String, Object?> taskRun({
  String id = 'trn-1',
  String status = 'pending',
  String parent = '',
  List<Object?> results = const [],
}) =>
    {
      'id': id,
      'taskId': 'tsk-1',
      'status': status,
      'parentTaskRunId': parent,
      'rootTaskRunId': '',
      'retries': 0,
      'attempts': <Object?>[],
      'results': results,
      'input': <Object?>[],
    };

void main() {
  group('startTask', () {
    test('posts the slug and positional input', () async {
      late http.Request seen;
      final render = renderWith((req) async {
        seen = req;
        return json(taskRun(), 202);
      });

      final run = await render.workflows.startTask('wf/sumSquares', [
        [2, 3, 4]
      ]);

      final body = jsonDecode(seen.body) as Map<String, Object?>;
      expect(body['task'], 'wf/sumSquares');
      expect(body['input'], [
        [2, 3, 4]
      ]);
      expect(seen.url.path, endsWith('/task-runs'));
      expect(run.status, TaskRunStatus.pending);
      expect(run.isChildRun, isFalse, reason: 'an empty parent id means root');
    });

    test('rejects input over the 4 MB limit before sending', () async {
      var called = false;
      final render = renderWith((_) async {
        called = true;
        return json(taskRun());
      });

      expect(
        () => render.workflows.startTask('wf/t', ['x' * (5 * 1024 * 1024)]),
        throwsA(isA<ArgumentError>()
            .having((e) => e.message.toString(), 'message', contains('4 MB'))),
      );
      expect(called, isFalse, reason: 'must not hit the network');
    });
  });

  group('status', () {
    test('treats both completed and succeeded as terminal success', () {
      // The API defines both, and which one an endpoint returns is not
      // something to guess at.
      for (final wire in ['completed', 'succeeded']) {
        final status = TaskRunStatus.fromWire(wire);
        expect(status.isTerminal, isTrue, reason: wire);
        expect(status.isSuccess, isTrue, reason: wire);
      }
      expect(TaskRunStatus.fromWire('running').isTerminal, isFalse);
      expect(TaskRunStatus.fromWire('failed').isSuccess, isFalse);
    });

    test('decodes an unknown status instead of throwing', () {
      // Workflows is beta; a new status must not break existing clients.
      final status = TaskRunStatus.fromWire('quarantined');
      expect(status, TaskRunStatus.unknown);
      expect(status.isTerminal, isFalse);
    });
  });

  group('task run details', () {
    test('unwrap the single result value', () {
      final details = TaskRunDetails.fromJson(
        taskRun(status: 'completed', results: [29]),
      );
      expect(details.result, 29);
      expect(details.isTerminal, isTrue);
    });
  });

  group('runTask', () {
    test('polls until the run is terminal', () async {
      final statuses = ['pending', 'running', 'completed'];
      var i = 0;
      final render = renderWith((req) async {
        if (req.method == 'POST') return json(taskRun(), 202);
        final status = statuses[i < statuses.length - 1 ? i++ : i];
        return json(taskRun(status: status, results: [42]));
      });

      final done = await render.workflows.runTask(
        'wf/t',
        const [],
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(done.status, TaskRunStatus.completed);
      expect(done.result, 42);
    });

    test('does not throw when the run fails', () async {
      // Failure is a result, not an exception: the caller wants the error
      // message, which lives on the run.
      final render = renderWith((req) async {
        if (req.method == 'POST') return json(taskRun(), 202);
        return json({
          ...taskRun(status: 'failed'),
          'error': 'Bad state: inventory check failed for sku-42',
        });
      });

      final done = await render.workflows.runTask(
        'wf/boom',
        const [],
        pollInterval: const Duration(milliseconds: 1),
      );

      expect(done.status, TaskRunStatus.failed);
      expect(done.error, contains('sku-42'));
    });
  });

  group('listTaskRuns', () {
    test('unwraps the resource envelope and follows cursors', () async {
      final pages = [
        [
          for (var i = 0; i < 2; i++)
            {'taskRun': taskRun(id: 'trn-$i'), 'cursor': 'c$i'},
        ],
        [
          {'taskRun': taskRun(id: 'trn-2'), 'cursor': 'c2'},
        ],
      ];
      var call = 0;
      final render = renderWith((_) async => json(pages[call++]));

      final runs =
          await render.workflows.listTaskRunsStream(pageSize: 2).toList();

      expect(runs.map((r) => r.id), ['trn-0', 'trn-1', 'trn-2']);
      expect(call, 2, reason: 'a short second page ends the listing');
    });

    test('repeats keys for multi-value filters', () async {
      late http.Request seen;
      final render = renderWith((req) async {
        seen = req;
        return json(<Object?>[]);
      });

      await render.workflows.listTaskRuns(workflowIds: ['a', 'b'], limit: 5);

      expect(seen.url.queryParametersAll['workflowId'], ['a', 'b']);
      expect(seen.url.queryParameters['limit'], '5');
    });
  });

  group('errors', () {
    test('a 404 arrives as a typed exception from render_api', () async {
      // The transport and its error mapping are shared with package:render_api
      // rather than duplicated here.
      final render = renderWith((_) async => http.Response('', 404));

      await expectLater(
        render.workflows.getTaskRun('trn-nope'),
        throwsA(isA<RenderNotFoundException>()),
      );
    });
  });

  group('batch helpers', () {
    test('classify a set of runs', () {
      final runs = [
        TaskRun.fromJson(taskRun(id: 'a', status: 'completed')),
        TaskRun.fromJson(taskRun(id: 'b', status: 'failed')),
        TaskRun.fromJson(taskRun(id: 'c', status: 'completed', parent: 'a')),
      ];

      expect(runs.allTerminal, isTrue);
      expect(runs.failed.map((r) => r.id), ['b']);
      expect(runs.children.map((r) => r.id), ['c']);
    });
  });
}
