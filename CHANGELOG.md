# Changelog

All notable changes to this project will be documented in this file.

## [0.5.0] — 2026-05-29

Added 10 sub-crates: macros, log, appender, mock, error, flame, attributes,
opentelemetry, serde. 141 parity specs across 30+ source files.

## [0.4.0] — 2026-05-28

Initial Crystal port of tokio-rs/tracing — 12 sub-crates with 141 parity specs.

### tracing-core

- Level / LevelFilter with inverted comparison semantics (`src/tracing/types.cr`)
- Kind bit flags: SPAN, EVENT, HINT (`src/tracing/types.cr`)
- Metadata: name, target, level, fields, kind, source location (`src/tracing/metadata.cr`)
- Field, FieldSet, ValueSet, Visit trait (`src/tracing/field.cr`)
- Callsite::Identifier, Interest, Interface, DefaultCallsite (`src/tracing/callsite.cr`)
- Callsite registry: lock-free linked list, CAS registration (`src/tracing/callsite.cr`)
- Span::Id, Attributes, Record, Current (`src/tracing/span.cr`)
- Parent enum: Root, Current, Explicit (`src/tracing/span.cr`)
- Event type with metadata, values, parent (`src/tracing/event.cr`)
- Subscriber trait + NoSubscriber (`src/tracing/subscriber.cr`)
- Dispatch: global default, fiber-local with_default (`src/tracing/dispatcher.cr`)
- Dispatchers manager: multi-dispatch, interest rebuild (`src/tracing/dispatcher.cr`)

### tracing facade

- Span handle: enter/exit/in_scope lifecycle (`src/tracing/facade_span.cr`)
- Entered/EnteredSpan guards with ensure-block exit (`src/tracing/facade_span.cr`)
- DSL: Tracing.span, .event, .info, .debug, .warn, .error, .trace (`src/tracing/facade_dsl.cr`)
- Macros: span!, event!, child_span!, info!, debug!, warn!, error!, trace!, *span! (`src/tracing/facade_macros.cr`)
- target: override on span/event methods (`src/tracing/facade_dsl.cr`)
- Tracing::Subscriber: with_default, set_global_default (`src/tracing/subscriber_conv.cr`)
- Tracing.instrument block wrapper (`src/tracing/facade_dsl.cr`)

### tracing-subscriber

- Registry: Subscriber impl, span storage, fiber-local span stack (`src/tracing-subscriber/registry.cr`)
- Registry.default, Registry#init (`src/tracing-subscriber/registry.cr`)
- Layer abstract class: on_event, on_new_span, on_enter, on_exit, enabled?, max_level_hint (`src/tracing-subscriber/layer.cr`)
- LayerContext with span lookup via subscriber (`src/tracing-subscriber/layer.cr`)
- Layered(S) generic subscriber: Layer + Subscriber composition (`src/tracing-subscriber/layer.cr`)
- LookupSpan trait + SpanRef with extensions access (`src/tracing-subscriber/lookup_span.cr`)
- Extensions type map: insert, get, replace, remove by type (`src/tracing-subscriber/extensions.cr`)
- LevelFilterLayer: verbosity-based filter as Layer (`src/tracing-subscriber/filter.cr`)
- EnvFilter: directive parsing + subscriber-level filter (`src/tracing-subscriber/env_filter.cr`)
- Directive parser: `target[span]=level` grammar (`src/tracing-subscriber/env_filter.cr`)
- FilterFn: closure-based filter (`src/tracing-subscriber/filter_fn.cr`)
- Targets: programmatic target-prefix filter (`src/tracing-subscriber/targets.cr`)
- FmtLayer: formatted output with compact, pretty, JSON, ANSI modes (`src/tracing-subscriber/fmt.cr`)
- FmtLayer: with_filter, FmtSpan config, make_writer (`src/tracing-subscriber/fmt.cr`)
- Filtered combinator + Layer#and_then (`src/tracing-subscriber/layer.cr`)
- NoOpLayer, Nil-as-Layer support (`src/tracing-subscriber/layer.cr`)
- MockSubscriber for testing (`src/tracing-subscriber/mock.cr`)
- SpanTrace context capture (`src/tracing-subscriber/span_trace.cr`)

### tracing-macros

- trace_dbg! macro: evaluate expr, emit event, return value (`src/tracing/facade_macros.cr`)

### tracing-log

- LogTracer: Crystal `Log::Backend` bridging to tracing events (`src/tracing-subscriber/log_tracer.cr`)
- Sync (:sync) and async (:async) dispatch modes

### tracing-appender

- NonBlocking: Channel + spawn fiber worker (`src/tracing-subscriber/appender.cr`)
- WorkerGuard: ensures flush on close (`src/tracing-subscriber/appender.cr`)
- RollingFileAppender: daily, hourly, minutely rotation (`src/tracing-subscriber/appender.cr`)

### tracing-attributes

- @[Instrument] annotation (`src/tracing/instrument_annotation.cr`)
- Tracing.instrument block wrapper (`src/tracing/facade_dsl.cr`)

### tracing-flame

- FlameLayer: folded stack output for inferno (`src/tracing-subscriber/flame.cr`)
- FlameGuard: ensures final flush + file close (`src/tracing-subscriber/flame.cr`)

### tracing-opentelemetry

- OpenTelemetryLayer: span/event conversion to OTel (`src/tracing-opentelemetry/layer.cr`)
- Span kind mapping: otel.kind → SpanKind (`src/tracing-opentelemetry/layer.cr`)
- Span status mapping: otel.status_code → StatusCode (`src/tracing-opentelemetry/layer.cr`)
- Dynamic span name: otel.name field (`src/tracing-opentelemetry/layer.cr`)
- Error event → exception detection (`src/tracing-opentelemetry/layer.cr`)
- Builder: with_level, with_target, with_location, with_threads

### tracing-serde

- FmtLayer.json: JSON output mode with structured fields (`src/tracing-subscriber/fmt.cr`)

### Dependencies

- lipgloss: terminal styling library
- perf_tools: fiber tracing and memory profiling
- opentelemetry-api + opentelemetry-sdk: OTel bridge
