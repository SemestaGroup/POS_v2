/// App-level bootstrap token used for pre-session calls (discover/login/
/// force-logout) before a real per-user session token is available.
///
/// Overridable via `--dart-define=FLINK_V2_FIXED_AUTH_TOKEN=...` so CI/CD can
/// inject and rotate it without touching source control. The literal default
/// below is kept only so local builds keep working out of the box; it should
/// be moved to a build-time secret (CI env var) and rotated on the backend
/// once that pipeline is in place, since anything compiled into the app is
/// still extractable from the release binary.
const kFlinkV2FixedAuthToken = String.fromEnvironment(
  'FLINK_V2_FIXED_AUTH_TOKEN',
  defaultValue:
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyIjoiIiwibmFtZSI6IiIsIkFQSV9USU1FIjoxNzY4Nzg5Mzg1fQ.ivZLnFkdbTXhYLgCpOuZwSoai6TO9NhbEsUb8uLZ3Qc',
);
