# render_workflows

> ## ⚠️ UNOFFICIAL
>
> An independent, community-built project. **Not affiliated with, endorsed by,
> or supported by [Render](https://render.com).**
>
> Render's own SDKs and documentation are at
> [render.com/docs](https://render.com/docs).

<a href="https://render.com"><img src="https://raw.githubusercontent.com/timmaffett/render_workflows_sdk/main/doc/render-logomark.svg" alt="Render" height="20" /></a>&nbsp;&nbsp;Built for **[Render](https://render.com)**.

<sub>The Render name and logo are trademarks of Render Services, Inc. The mark
is reproduced unaltered from Render's brand kit, referentially, to identify the
service these packages work with — not to suggest any endorsement.</sub>

A Dart client for [Render Workflows](https://render.com/docs/workflows) —
start, watch and cancel task runs.

Mirrors Render's official TypeScript SDK, so its documentation carries over:

```dart
final render = Render();                       // reads RENDER_API_KEY

final run = await render.workflows.runTask(
  'my-workflow/sumSquares',
  [[2, 3, 4]],
);
print(run.result);                             // 29

render.close();
```

## Why this is separate from `render_api`

Render splits the same way: `@renderinc/sdk` runs tasks, `@api/render-api`
covers the REST surface. Workflow *services* — creating them, deploying
versions, listing task definitions — are plain REST and live in
`package:render_api`.

The split is also practical: `render_api` generates 208 operations, and a
Flutter app that only triggers a task shouldn't have all of them crowding
autocomplete.

Unlike Render's two packages, this one *depends* on `render_api` rather than
duplicating the transport. Theirs are independent only because two different
toolchains produced them.

## What it adds over the raw endpoints

| | |
| --- | --- |
| `runTask` / `waitFor` | Polls to completion. Works on Flutter Web, where SSE does not |
| `listTaskRunsStream` | Walks cursors for you |
| 4 MB input cap | Checked locally, so an oversized payload fails by name |
| `TaskRunStatus` | Treats terminality as data — the API defines both `completed` *and* `succeeded` |
| Errors | Typed, and carrying a hint. Render answers `500` for an unknown task run id, not `404` |

## Method names

`startTask`, `runTask`, `getTaskRun`, `cancelTaskRun`, `listTaskRuns`,
`taskRunEvents` — exactly as the TypeScript SDK names them. `waitFor` and
`listTaskRunsStream` are additions where Dart offers something TypeScript has
no equivalent for.

## Watching runs

`runTask` and `waitFor` poll, and work everywhere.

`taskRunEvents` streams server-sent events instead, but **will not work on
Flutter Web with the default HTTP client** — `package:http`'s `BrowserClient`
buffers whole responses. Inject a streaming client (`package:fetch_client`)
there, or poll.

## Testing

```bash
dart test                      # offline, no credentials needed
dart run example/smoke.dart    # live, needs RENDER_API_KEY
```
