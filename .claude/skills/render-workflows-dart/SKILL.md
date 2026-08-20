---
name: render-workflows-dart
description: Uses package:render_workflows, an unofficial Dart client for running Render Workflows tasks (not affiliated with Render) — starting runs, waiting for completion, fan-out to subtasks, listing and cancelling runs, and streaming run events. Use when Dart code needs to trigger a Render workflow task, poll a task run to completion, or inspect task run history. For writing the tasks themselves in Dart, use the render-dart skill instead.
license: MIT
compatibility: Dart 3.9+. Reads RENDER_API_KEY. Depends on package:render_api. Render Workflows is in beta.
metadata:
  author: Tim Maffett
  version: "1.0.0"
  category: workflows
---

# Running Render Workflows tasks from Dart

**Unofficial.** A community package, not affiliated with, endorsed by, or
supported by Render. Do not present it as Render's own tooling.

Mirrors Render's official TypeScript SDK, so its documentation carries over:
`startTask`, `runTask`, `getTaskRun`, `cancelTaskRun`, `listTaskRuns`,
`taskRunEvents`.

**This is for *calling* tasks.** Writing them in Dart is the `render-dart`
skill. Creating and deploying workflow *services* is plain REST — use
`render-api-dart`.

## Calling it

```dart
import 'package:render_workflows/render_workflows.dart';

final render = Render();                     // reads RENDER_API_KEY
try {
  final run = await render.workflows.runTask(
    'my-workflow/sumSquares',
    [[2, 3, 4]],
  );
  print(run.result);                         // 29
} finally {
  render.close();
}
```

Methods hang off `render.workflows`, not `render` directly. A task slug is
`workflow-slug/task-name`, optionally pinned with `:version`.

## Waiting

`runTask` starts and waits. `startTask` returns immediately, and `waitFor`
polls a run you already have:

```dart
final run = await render.workflows.startTask('wf/slow', []);
final done = await render.workflows.waitFor(run.id, timeout: Duration(minutes: 5));
```

**Do not hand-roll the polling.** `waitFor` watches the run's **own** terminal
status. A version that watches `attempts[].status` reports a run as finished
while it is still going, because an attempt completes before the run does.

`taskRunEvents` streams server-sent events instead, and **will not work on
Flutter Web with the default HTTP client** — `package:http`'s `BrowserClient`
buffers whole responses. Inject a streaming client there, or poll.

## Results and failures

```dart
if (done.status.isTerminal) {
  print(done.result);        // first result, or null
  print(done.error);         // message plus stack, when it failed
}
```

`TaskRunStatus` treats terminality as data because the API defines both
`completed` and `succeeded` — do not collapse it into a string comparison.

## Limits

**Input is capped at 4 MB**, checked locally so an oversized payload fails by
name rather than arriving as a generic rejection.

Each run gets its own instance, so fan-out via subtasks is genuinely parallel —
but a run's own start-up is of the order of a few hundred milliseconds, which
dominates trivial work.

## Errors

Typed, and carrying hints. Render answers `500`, not `404`, for an unknown task
run id — read the hint before assuming an outage.
