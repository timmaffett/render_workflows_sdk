## 0.1.4

Findings from a security audit of this package.

- **Path parameters are percent-encoded.** `getTaskRun` and `cancelTaskRun`
  interpolated a task run id straight into the URL. The cancel is the severe
  one: unencoded, `cancelTaskRun('../workflows/wfl-x')` sent
  `DELETE /v1/workflows/wfl-x` — the caller asked to cancel a run and deleted a
  workflow instead, because `Uri` normalises the `..` away before the request
  leaves. A task run id is exactly the sort of value that arrives in a request.
- **The event stream's query is built through `Uri`, not by concatenation.** An
  id containing `&` appended query parameters of its own choosing; a `#`
  truncated the query.
- **A single server-sent event is bounded at 16 MB.** An SSE frame ends at a
  blank line, so until one arrived the buffer held whatever the peer chose to
  send. Render does not do this; a client library should not let a network peer
  decide how much memory it uses.
- Requires `render_api ^0.1.7`, which carries the same path-encoding fix for the
  208 generated operations.

## 0.1.3

- The `Render()` example said `// reads RENDER_API_KEY` without saying from
  where. Now `// token from the RENDER_API_KEY env var`, in the README and in
  the library doc comment pub.dev renders on the API page.

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
