// Live smoke test against a deployed Render workflow.
//
//   dart run example/smoke.dart
//
// Requires RENDER_API_KEY. Task runs cost a fraction of a cent.
//
// Shows the division of labour: package:render_api finds the workflow (plain
// REST), package:render_workflows runs its tasks.
import 'dart:io';

import 'package:render_api/render_api.dart' as api;
import 'package:render_workflows/render_workflows.dart';

const _workflowName = 'render-dart-workflow-test';

Future<void> main() async {
  final rest = api.RenderApi();
  final render = Render();
  var failures = 0;

  void check(String label, bool ok, [Object? detail]) {
    stdout.writeln('${ok ? '  ok  ' : ' FAIL '} $label'
        '${detail == null ? '' : '  -> $detail'}');
    if (!ok) failures++;
  }

  try {
    stdout.writeln('\n-- find the workflow (render_api) --');
    final workflows = await rest.listWorkflows(limit: 20);
    final matches = workflows
        .map((w) => w.workflow)
        .where((w) => w.name == _workflowName)
        .toList();
    check('found $_workflowName', matches.isNotEmpty,
        matches.isEmpty ? null : matches.first.id);
    if (matches.isEmpty) return;

    final slug = matches.first.slug ?? matches.first.name;

    stdout.writeln('\n-- run a task with fan-out (render_workflows) --');
    final sum = await render.workflows.runTask(
      '$slug/sumSquares',
      [
        [2, 3, 4]
      ],
      timeout: const Duration(minutes: 3),
    );
    check('sumSquares succeeded', sum.status.isSuccess, sum.status.name);
    check('sumSquares == 29', sum.result == 29, sum.result);

    stdout.writeln('\n-- child runs --');
    final children = await render.workflows
        .listTaskRunsStream(rootTaskRunIds: [sum.id], max: 20)
        .toList();
    check('three child runs', children.children.length == 3,
        '${children.children.length} of ${children.length} total');

    stdout.writeln('\n-- failure path --');
    final boom = await render.workflows.runTask(
      '$slug/boom',
      const [],
      timeout: const Duration(minutes: 3),
    );
    check('boom failed', boom.status == TaskRunStatus.failed, boom.status.name);
    check('Dart message survived', boom.error?.contains('sku-42') ?? false,
        boom.error?.split('\n').first);

    stdout.writeln('\n-- guardrails --');
    try {
      await render.workflows.startTask('$slug/boom', ['x' * (5 * 1024 * 1024)]);
      check('4 MB input rejected locally', false, 'no error thrown');
    } on ArgumentError catch (e) {
      check('4 MB input rejected locally', true,
          e.message.toString().split('.').first);
    }

    try {
      await render.workflows.getTaskRun('trn-does-not-exist');
      check('unknown run id raises', false, 'no error thrown');
    } on RenderApiException catch (e) {
      // Render answers 500 here rather than 404, which is why the hint
      // matters more than the status code.
      check('unknown run id raises with a usable hint',
          e.hint?.contains('trn-') ?? false, '${e.statusCode}: ${e.hint}');
    }
  } on RenderException catch (e) {
    stdout.writeln('\nRender error:\n$e');
    failures++;
  } finally {
    render.close();
    rest.close();
  }

  stdout.writeln(failures == 0
      ? '\nAll checks passed.'
      : '\n$failures check(s) failed.');
  exit(failures == 0 ? 0 : 1);
}
