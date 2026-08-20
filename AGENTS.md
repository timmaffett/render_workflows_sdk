# Working on render_workflows

A Dart client for running Render Workflows tasks. Mirrors Render's official
TypeScript SDK, so its documentation carries over.

This file is for coding agents. `README.md` explains the package to a user.

## Using it

```dart
final render = Render();         // token from the RENDER_API_KEY env var
final run = await render.workflows.runTask('my-workflow/sumSquares', [[2, 3, 4]]);
print(run.result);                        // 29
render.close();
```

Methods hang off `render.workflows`, not `render` directly.

`dart test` — 11 tests, offline. `dart run example/smoke.dart` is live and costs
a fraction of a cent.

## Use waitFor; do not hand-roll polling

`runTask` and `waitFor` poll the run's **own** terminal status.

A hand-written version that watches `attempts[].status` will report a run as
finished while it is still going — an attempt completes before the run does.
This has been got wrong more than once. If you need custom behaviour, pass
`pollInterval`/`timeout` rather than reimplementing the loop.

`taskRunEvents` streams SSE instead, and **will not work on Flutter Web with the
default HTTP client** — `package:http`'s `BrowserClient` buffers whole
responses. Inject a streaming client there, or poll.

## Boundaries

Task *running* lives here. Workflow *services* — creating them, deploying
versions, listing task definitions — are plain REST and belong in
`package:render_api`. Render splits the same way. Do not duplicate REST
operations into this package.

Unlike Render's two packages, this one **depends** on `render_api` rather than
duplicating transport, errors and pagination.

## Before publishing to pub.dev

The dependency on `render_api` is **by path**. That must become a version
constraint first, and `render_api` must publish first. Nothing else blocks it.

## Traps

**The 4 MB input cap is checked locally**, so an oversized payload fails by name
instead of arriving as a generic API rejection. Keep it.

**`TaskRunStatus` treats terminality as data** because the API defines both
`completed` and `succeeded`. Do not collapse them into a string comparison.
