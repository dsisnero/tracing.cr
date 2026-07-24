# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Added

- `Tracing::Log` module with level conversion utilities: `level_as_log`, `level_filter_as_log`, `severity_as_trace` (`src/tracing/log.cr`)
- EnvFilter field-value directive parsing — `{field=val}` syntax in span-scoped directives (e.g., `my_app[db{query=auth}]=debug`)
- EnvFilter runtime field-value matching via `FieldCollector` visitor — span fields tracked on `on_new_span`/`on_record`, matched against `FieldMatch` in `enabled?` for events
- `LookupSpan#current_span_id` — abstract method + `Layered` delegation, used by EnvFilter to resolve the active span during field-value checks

### Changed

- `EnvFilter` field tracking in `Registry`: `@span_fields` populated on span creation and record, cleaned up on `on_close`
- `Directive.parse` accepts optional `{field=val,...}` brace syntax after span name
- Moved `Tracing::OpenTelemetryLayer` into the optional sibling shard `tracing-opentelemetry`; the base `tracing` shard no longer depends on `opentelemetry-api` or `opentelemetry-sdk`

### Verification

- `crystal tool format --check src spec`
- `ameba src spec`
- `crystal spec` (`314` examples)

### Documentation

- Updated `README.md` with EnvFilter field-value example and AsLog/AsTrace usage
- Updated `docs/architecture.md` — expanded `env_filter.cr` description, added `log.cr` row
- Updated `docs/development.md` — added `log.cr` to source tree
- Updated docs for the `tracing-opentelemetry` companion shard split

## [0.5.1] — 2026-07-20

This release reflects the current `src/` surface and repo layout.

### Added / Completed

- Completed `Tracing.fmt` builder API with current delegates:
  `compact`, `pretty`, `json`, `with_max_level`, `with_filter_reloading`,
  `flatten_event`, `with_current_span`, `with_span_list`,
  `with_thread_ids`, `with_thread_names`, and `without_time`
- Completed `FmtLayer` JSON, pretty, compact, ANSI, timer, test-writer, and
  `MakeWriter` support under `src/tracing/subscriber/`
- Completed reloadable filter/layer support via `Tracing::Reload` and `Tracing::Handle`
- Completed appender support: `NonBlocking`, `WorkerGuard`,
  `RollingFileAppender`, `Rotation`, and builder-style file naming / pruning
- Completed `Tracing::FlameLayer` folded-stack output for inferno-compatible
  flamegraph generation
- Completed `Tracing::OpenTelemetryLayer` span export on close, contextual
  event export, context activation, error-to-status mapping, and dynamic span metadata
- Completed concurrency helpers under `src/tracing/concurrency*`:
  traced channel wrappers, traced fiber spawn helpers, and subscriber propagation
- Completed current formatting/lookup/filter combinator surface in
  `src/tracing/subscriber/`

### Verification

- `crystal tool format --check src spec`
- `ameba src spec`
- `crystal spec` (`283` examples)

### Documentation

- Updated `README.md`, `CHANGELOG.md`, and `docs/*` to the current `src/`
  layout: `src/tracing/core`, `src/tracing/subscriber`,
  `src/tracing/opentelemetry`, and `src/tracing/concurrency*`

## [0.5.0] — 2026-05-29

- Added the first full sub-crate expansion around the core port:
  macros, log bridge, appender, mock subscriber, error/span-trace support,
  flame output, attributes, OpenTelemetry, and serde-oriented JSON formatting

## [0.4.0] — 2026-05-28

- Initial Crystal port of the upstream `tracing`, `tracing-core`, and
  `tracing-subscriber` foundations
