# Architecture

This repository ports the `tokio-rs/tracing` stack into Crystal and keeps the
same high-level split:

- core tracing data structures and dispatch
- user-facing facade and macros
- subscriber/layer/filter/formatting stack
- adjunct sub-crates such as flame, appender, log bridge, attributes, and OpenTelemetry

## Current Source Layout

| Area | Crystal Source | Notes |
|------|----------------|-------|
| Entry point | `src/tracing.cr` | Requires and re-exports the shipped surface |
| Core | `src/tracing/core/` | Levels, metadata, fields, callsites, spans, events, subscriber trait, dispatch |
| Facade | `src/tracing/` | `Tracing.span`, `Tracing.event`, `Tracing::Span`, macros, subscriber convenience |
| Subscriber stack | `src/tracing/subscriber/` | Registry, layers, filters, formatting, reload, appenders, flame, log bridge, mock, span trace |
| OpenTelemetry | `src/tracing/opentelemetry/` | `Tracing::OpenTelemetryLayer` |
| Concurrency | `src/tracing/concurrency*` | Fiber propagation and traced channels |

## Entry Point

[src/tracing.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing.cr:1) wires the port together.

It currently:

- requires all core and facade files
- requires the subscriber stack
- requires `src/tracing/opentelemetry/layer.cr`
- exposes `Tracing.fmt` and `Tracing.fmt_layer`
- aliases the core public types (`Level`, `LevelFilter`, `Metadata`, `Dispatch`, and nested field/callsite/span aliases)

## Core Runtime

The runtime core lives in `src/tracing/core/`.

| File | Purpose |
|------|---------|
| `types.cr` | `Level`, `LevelFilter`, parse errors, kind flags, callsite interest |
| `metadata.cr` | span and event metadata |
| `field.cr` | field descriptors, field sets, value sets, visitor protocol |
| `callsite.cr` | callsite abstraction and registry |
| `span.cr` | `Span::Id`, attributes, record values, current span, parent relationships |
| `event.cr` | event value + parent/context handling |
| `subscriber.cr` | `Core::Subscriber` trait and `NoSubscriber` |
| `dispatcher.cr` | global/fiber-local dispatch and default scoping |

### Core Data Flow

Typical span creation flows like this:

1. `span!(...)` or `Tracing.span(...)` builds metadata and values.
2. `Dispatch.current` resolves the active subscriber.
3. `subscriber.enabled(metadata)` gates the callsite.
4. `subscriber.new_span(attrs)` allocates a span id.
5. `Tracing::Span` wraps the id and metadata for user-facing lifecycle control.
6. `span.enter` / `span.in_scope` drives `subscriber.enter(id)` and `subscriber.exit(id)`.
7. `Registry` tracks the current span stack per fiber and stores per-span data.

## Facade Layer

The facade stays under `src/tracing/`.

| File | Purpose |
|------|---------|
| `facade_span.cr` | `Tracing::Span`, entered guards, `#record`, `#follows_from`, `#close` |
| `facade_dsl.cr` | `Tracing.span`, `.event`, `.info`, `.debug`, `.warn`, `.error`, `.trace`, `.instrument` |
| `facade_macros.cr` | `span!`, `event!`, `info!`, `debug_span!`, `trace_dbg!`, and related macros |
| `subscriber_conv.cr` | `Tracing::Subscriber.with_default` and `.set_global_default` |
| `instrument_annotation.cr` | `@[Tracing::Instrument]` |

## Subscriber Stack

The subscriber stack lives in `src/tracing/subscriber/`.

### Registry and Lookup

| File | Purpose |
|------|---------|
| `registry.cr` | concrete subscriber implementation and span storage |
| `lookup_span.cr` | `LookupSpan`, `SpanRef`, `Scope`, `LayerContext#event_span` |
| `extensions.cr` | per-span typed storage |

`Registry` owns span data. `SpanRef` provides higher-level access to stored
span metadata and extensions. `Scope#from_root` is used by the JSON formatter
to emit root-to-leaf span lists.

### Layers and Filters

| File | Purpose |
|------|---------|
| `layer.cr` | `Layer`, `LayerContext`, `Layered(S)`, `Filtered`, `NoOpLayer` |
| `filter.cr` | `LevelFilterLayer` |
| `env_filter.cr` | `Directive` parser (target, span-name, field-value `{field=val}`), `FieldMatch`, `EnvFilter` layer with runtime field-value matching |
| `filter_fn.cr` | closure-based metadata filters |
| `targets.cr` | target-prefix filters |
| `filter_ext.cr` | `and`, `or`, `not` combinators |
| `reload.cr` | reloadable wrapper layer and handle |

Layer composition is runtime polymorphic except for `Layered(S)`, which uses a
single generic parameter to preserve type-safe subscriber nesting.

### Formatting

| File | Purpose |
|------|---------|
| `fmt.cr` | `FmtLayer`, JSON/pretty/compact output, writer selection |
| `fmt_builder.cr` | `Tracing.fmt` builder surface |
| `fmt/time.cr` | time formatters |
| `fmt/format.cr` | field/event formatting infrastructure |
| `fmt/writer.cr` | `MakeWriter` and combinators |

The formatting stack supports:

- compact, pretty, and JSON modes
- ANSI control
- thread/fiber id and name output
- `flatten_event`, `with_current_span`, `with_span_list` JSON options
- `with_test_writer`
- `MakeWriter` combinators such as max/min level, metadata predicate, tee, and fallback

## Appender, Flame, Log, Mock, Error

These are implemented directly under `src/tracing/subscriber/`.

| File | Purpose |
|------|---------|
| `appender.cr` | `NonBlocking`, `WorkerGuard`, `RollingFileAppender`, `Rotation` |
| `flame.cr` | `FlameLayer`, `FlameGuard` |
| `log.cr` | `Tracing::Log` — level conversions between tracing and `::Log` (`level_as_log`, `level_filter_as_log`, `severity_as_trace`) |
| `log_tracer.cr` | Crystal `Log` bridge |
| `mock.cr` | `MockSubscriber` |
| `span_trace.cr` | `SpanTrace` capture and formatting |

`FlameLayer` writes inferno-compatible folded stack output. It does not render
SVG itself; downstream tools such as `inferno-flamegraph` consume the output.

## OpenTelemetry Bridge

`src/tracing/opentelemetry/layer.cr` contains the OTel bridge.

Current responsibilities:

- create OTel spans when tracing spans are created
- map tracing metadata and fields into OTel attributes
- map error events into OTel status and exception-style events
- activate/deactivate current OTel trace/span on fiber enter/exit
- export root traces when the owning tracing span closes

This is a bridge layer, not a full tracing viewer or Chrome trace exporter.

## Concurrency Helpers

The concurrency surface is split across:

- `src/tracing/concurrency.cr`
- `src/tracing/concurrency/fiber.cr`
- `src/tracing/concurrency/fiber_ext.cr`
- `src/tracing/concurrency/channel.cr`
- `src/tracing/concurrency/channel_ext.cr`

These helpers preserve tracing dispatch/span context across spawned fibers and
wrap channels with send/receive instrumentation.
