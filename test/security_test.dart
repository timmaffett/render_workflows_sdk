import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:render_workflows/render_workflows.dart';
import 'package:test/test.dart';

/// Properties that are security boundaries rather than conveniences.
///
/// A task run id is exactly the sort of value that arrives in a request and is
/// handed straight to a client library.
void main() {
  Future<http.Request> capture(Future<void> Function(Render) call) async {
    late http.Request seen;
    final render = Render(
      token: 'test-token',
      httpClient: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode(<String, Object?>{}), 200, headers: {
          'content-type': 'application/json',
        });
      }),
    );
    try {
      await call(render);
    } catch (_) {
      // The request is captured before any decoding of the empty body fails,
      // and the request is what is under test.
    }
    return seen;
  }

  test('a traversing id cannot redirect a GET', () async {
    final request = await capture(
      (r) => r.workflows.getTaskRun('../workflows/wfl-x'),
    );
    expect(request.url.path, endsWith('/task-runs/..%2Fworkflows%2Fwfl-x'));
    expect(request.url.path, isNot(endsWith('/workflows/wfl-x')));
  });

  test('a traversing id cannot turn a cancel into a different DELETE', () async {
    // The severe one. Unencoded, this sent DELETE /v1/workflows/wfl-x -- the
    // caller asked to cancel a task run and would have deleted a workflow.
    final request = await capture(
      (r) => r.workflows.cancelTaskRun('../workflows/wfl-x'),
    );
    expect(request.method, 'DELETE');
    expect(request.url.path, endsWith('/task-runs/..%2Fworkflows%2Fwfl-x'));
    expect(request.url.path, isNot(contains('/workflows/wfl-x')));
  });

  test('an ordinary id is untouched', () async {
    final request = await capture((r) => r.workflows.getTaskRun('trn-abc123'));
    expect(request.url.path, endsWith('/task-runs/trn-abc123'));
  });

  test('an event id cannot smuggle query parameters', () async {
    // taskRunEvents built its query by concatenation, so an id containing `&`
    // appended parameters of its own choosing and a `#` truncated the query.
    late http.BaseRequest seen;
    final render = Render(
      token: 't',
      httpClient: MockClient((request) async => http.Response('{}', 200)),
    );
    final probe = MockClient((request) async {
      seen = request;
      return http.Response('', 200, headers: {'content-type': 'text/event-stream'});
    });
    await render.workflows
        .taskRunEvents(['trn-a&limit=999', 'trn-b'], httpClient: probe)
        .toList();

    expect(seen.url.queryParametersAll['taskRunIds'], ['trn-a&limit=999', 'trn-b']);
    expect(seen.url.queryParameters.containsKey('limit'), isFalse);
    expect(seen.url.query, contains('%26'));
  });
}
