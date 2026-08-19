/// A Dart client for [Render Workflows](https://render.com/docs/workflows).
///
/// Mirrors Render's official TypeScript SDK: `Render().workflows.startTask(...)`.
/// Workflow *services* — creating them, deploying versions, listing task
/// definitions — are plain REST and live in `package:render_api`, which Render
/// splits the same way.
///
/// ```dart
/// final render = Render();                       // reads RENDER_API_KEY
/// final run = await render.workflows.runTask(
///   'my-workflow/sumSquares',
///   [[2, 3, 4]],
/// );
/// print(run.result);                             // 29
/// render.close();
/// ```
library;

import 'package:http/http.dart' as http;
import 'package:render_api/render_api.dart';

import 'src/workflows_client.dart';

export 'package:render_api/render_api.dart'
    show
        RenderApiClient,
        RenderException,
        RenderApiException,
        RenderAuthException,
        RenderClientException,
        RenderNetworkException,
        RenderNotFoundException,
        RenderPaymentRequiredException,
        RenderRateLimitException,
        RenderServerException,
        kRenderBaseUrl,
        kRenderLocalDevUrl;

export 'src/pagination.dart' show Page, paginate;
export 'src/status.dart';
export 'src/task_run.dart';
export 'src/workflows_client.dart' show WorkflowsClient, TaskRunListX;

/// Entry point for Render Workflows.
///
/// Named to match Render's TypeScript SDK, where `new Render({token})` exposes
/// a `workflows` client. Construct one and keep it: it owns an HTTP client, so
/// call [close] when finished.
class Render {
  /// Creates a client.
  ///
  /// [token] defaults to the `RENDER_API_KEY` environment variable. There is
  /// no environment on the web, so a token must be passed explicitly there.
  Render({
    String? token,
    String? baseUrl,
    http.Client? httpClient,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 30),
  }) : this.fromClient(
          RenderApiClient(
            token: token,
            baseUrl: baseUrl,
            httpClient: httpClient,
            maxRetries: maxRetries,
            timeout: timeout,
          ),
        );

  /// Wraps an existing [RenderApiClient] — useful in tests, or to share one
  /// transport with `package:render_api`.
  Render.fromClient(this.client) : workflows = WorkflowsClient(client);

  /// Points at the CLI's local task server (`render workflows dev`).
  factory Render.localDev({String? url, http.Client? httpClient}) =>
      Render.fromClient(
        RenderApiClient.localDev(url: url, httpClient: httpClient),
      );

  /// The underlying transport, shared with `package:render_api`.
  final RenderApiClient client;

  /// Starting, watching and cancelling task runs.
  final WorkflowsClient workflows;

  /// Releases the underlying HTTP client.
  void close() => client.close();
}
