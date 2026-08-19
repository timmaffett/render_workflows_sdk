/// Lifecycle of a task run.
///
/// The API defines *both* `completed` and `succeeded`, and which one an
/// endpoint returns is not something to guess at — so terminality is treated
/// as data rather than hard-coded against a single name.
///
/// Unrecognised values decode to [unknown] rather than throwing. Render
/// documents Workflows as beta with breaking changes expected, and a status
/// added next month must not crash a client that is otherwise fine.
enum TaskRunStatus {
  pending('pending'),
  running('running'),
  completed('completed'),
  succeeded('succeeded'),
  failed('failed'),
  canceled('canceled'),
  paused('paused'),

  /// A status this package does not recognise. The literal value is on the
  /// originating model's `rawStatus`.
  unknown('');

  const TaskRunStatus(this.wireValue);

  final String wireValue;

  /// Whether the run has finished and will not change again.
  bool get isTerminal => switch (this) {
        completed || succeeded || failed || canceled => true,
        pending || running || paused || unknown => false,
      };

  /// Whether the run finished without error.
  bool get isSuccess => this == completed || this == succeeded;

  static TaskRunStatus fromWire(String? value) => values.firstWhere(
        (s) => s.wireValue == value,
        orElse: () => unknown,
      );
}

/// Instance size a task run executes on.
///
/// `proPlus` and larger require requesting access for your workspace.
enum TaskPlan {
  starter('starter'),
  standard('standard'),
  pro('pro'),
  proPlus('pro_plus'),
  proMax('pro_max'),
  proUltra('pro_ultra');

  const TaskPlan(this.wireValue);

  final String wireValue;
}
