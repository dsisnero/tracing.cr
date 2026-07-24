# Testing

## Main Test Command

```bash
crystal spec
```

The current suite contains `332` examples in `spec/tracing_spec.cr`.

## Quality Gates

Use the same gates in local validation and review:

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

## Test Organization

The suite is currently consolidated in `spec/tracing_spec.cr` and covers the
shipped surface across these areas:

- core level, metadata, field, span, event, parent, and dispatch behavior
- facade DSL and macro behavior
- registry, span lookup, extensions, and layer lifecycle
- filter types (`LevelFilterLayer`, `EnvFilter`, `FilterFn`, `Targets`)
- formatting (`FmtLayer`, JSON options, timers, writers, builder API)
- reload support
- appender support (`NonBlocking`, rolling files)
- log bridge, mock subscriber, and `SpanTrace`
- flame output
- OpenTelemetry bridge
- concurrency helpers

## Focused Test Runs

Examples:

```bash
crystal spec spec/tracing_spec.cr --fail-fast --error-trace --verbose
crystal spec spec/tracing_spec.cr -e "OpenTelemetry"
crystal spec spec/tracing_spec.cr -e "FlameLayer"
```

## Writing New Tests

1. Start from the upstream Rust behavior in `vendor/tracing/`.
2. Port the contract, not the Rust syntax.
3. Prefer assertions on observable behavior over storage internals.
4. Use `Dispatch.with_default` to scope subscriber state in tests.
5. Avoid process-global setup when a scoped dispatch is enough.

## When Docs Need Updating

If a test addition reveals that public behavior changed, update:

- `README.md`
- `CHANGELOG.md`
- the relevant file in `docs/`

This repo uses the test suite as the strongest source of truth for shipped behavior.
