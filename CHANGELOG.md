## 0.1.2

- Clean up README

## 0.1.1

- Adds `example/example.dart`, and formats the package with `dart format`.
  Together these take the pub.dev score from 140/160 to 160/160 — the two
  deductions were a missing example and formatting, both found with `pana`
  before publishing rather than after.
- README now names `render-dart` on npm, for writing task bodies in Dart.

## 0.1.0

Initial release.

- Start, watch, list and cancel Render Workflows task runs.
- Method names mirror Render's official TypeScript SDK — `startTask`,
  `runTask`, `getTaskRun`, `cancelTaskRun`, `listTaskRuns`, `taskRunEvents` —
  so its documentation carries over.
- `waitFor` polls a run's own terminal status, which is what makes it correct:
  an attempt reaches a terminal state before the run does.
- `listTaskRunsStream` walks cursors for you.
- Render's 4 MB input limit is checked locally, so an oversized payload fails
  by name rather than as a generic rejection.
- `TaskRunStatus` treats terminality as data, because the API defines both
  `completed` and `succeeded`.
- Builds on `package:render_api` rather than duplicating transport, errors and
  pagination.
