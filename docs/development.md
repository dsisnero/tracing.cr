# Development

## Setup

```bash
shards install
```

## Source Tree

```text
src/
├── tracing.cr
├── tracing/
│   ├── core/
│   │   ├── types.cr
│   │   ├── metadata.cr
│   │   ├── field.cr
│   │   ├── callsite.cr
│   │   ├── span.cr
│   │   ├── event.cr
│   │   ├── subscriber.cr
│   │   └── dispatcher.cr
│   ├── facade_dsl.cr
│   ├── facade_macros.cr
│   ├── facade_span.cr
│   ├── instrument_annotation.cr
│   ├── opentelemetry/
│   │   └── layer.cr
│   └── subscriber/
│       ├── appender.cr
│       ├── env_filter.cr
│       ├── extensions.cr
│       ├── filter.cr
│       ├── filter_ext.cr
│       ├── filter_fn.cr
│       ├── flame.cr
│       ├── fmt.cr
│       ├── fmt_builder.cr
│       ├── layer.cr
│       ├── log.cr
│       ├── log_tracer.cr
│       ├── lookup_span.cr
│       ├── mock.cr
│       ├── registry.cr
│       ├── reload.cr
│       ├── span_trace.cr
│       └── targets.cr
├── tracing/concurrency.cr
└── tracing/concurrency/
    ├── channel.cr
    ├── channel_ext.cr
    ├── fiber.cr
    └── fiber_ext.cr
```

## Key Entry Points

- `src/tracing.cr`: public requires and aliases
- `src/tracing/subscriber/fmt_builder.cr`: `Tracing.fmt`
- `src/tracing/subscriber/fmt.cr`: `FmtLayer`
- `src/tracing/subscriber/registry.cr`: `Registry`
- `src/tracing/subscriber/layer.cr`: `Layer`, `Layered(S)`, `Filtered`
- `src/tracing/opentelemetry/layer.cr`: `OpenTelemetryLayer`
- `src/tracing/subscriber/appender.cr`: `NonBlocking`, `RollingFileAppender`
- `src/tracing/subscriber/flame.cr`: `FlameLayer`

## Quality Gates

Run all three before handing off code:

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

Current suite size: `332` examples.

## Typical Workflow

1. Read the upstream implementation under `vendor/tracing/`.
2. Locate the corresponding Crystal subsystem in `src/`.
3. Add or adjust focused coverage in `spec/tracing_spec.cr`.
4. Implement the smallest behaviorally correct change.
5. Run the quality gates.
6. Update docs if the public surface moved.
7. Update `plans/parity.md` and the relevant inventory file when parity status changed.

## Useful Commands

```bash
crystal spec spec/tracing_spec.cr --fail-fast --error-trace --verbose
crystal tool format --check src spec
ameba src
ameba spec
```

## Inventory and Parity Tools

Useful scripts already in the repo:

```bash
./scripts/check_port_inventory.sh . plans/inventory/rust_port_inventory.tsv vendor/tracing rust
./scripts/check_source_parity.sh . plans/inventory/rust_source_parity.tsv vendor/tracing
./scripts/check_test_parity.sh . plans/inventory/rust_test_parity.tsv vendor/tracing
```

Use these for drift checks. The TSV inventory files are still curated ledgers,
not generated source of truth.
