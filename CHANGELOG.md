# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### tracing-core

- Level / LevelFilter with inverted comparison semantics matching upstream (`src/tracing/types.cr`)
- Kind bit flags: SPAN, EVENT, HINT (`src/tracing/types.cr`)
- Metadata: name, target, level, fields, kind, source location (`src/tracing/metadata.cr`)
- Field, FieldSet, ValueSet, Visit trait for typed key-value data (`src/tracing/field.cr`)
- Callsite::Identifier, Interest, Interface, DefaultCallsite (`src/tracing/callsite.cr`, `src/tracing/types.cr`)
- Callsite registry: lock-free linked list with CAS registration, interest caching (`src/tracing/callsite.cr`)
- Span::Id (non-zero u64), Attributes, Record, Current (`src/tracing/span.cr`)
- Parent enum: Root, Current, Explicit(id) (`src/tracing/span.cr`)
- Event type with metadata, values, parent (`src/tracing/event.cr`)
- Subscriber trait: new_span, enter, exit, event, record, enabled, register_callsite (`src/tracing/subscriber.cr`)
- NoSubscriber: no-op subscriber implementation (`src/tracing/subscriber.cr`)
- Dispatch: global default, fiber-local with_default, spawn/event forwarding (`src/tracing/dispatcher.cr`)
- Dispatchers manager: multi-dispatch with callsite interest rebuild (`src/tracing/dispatcher.cr`)

### tracing facade

- Span handle: enter/exit/in_scope lifecycle, disabled? detection (`src/tracing/facade_span.cr`)
- Entered/EnteredSpan guards with ensure-block exit (`src/tracing/facade_span.cr`)
- DSL methods: Tracing.span, .event, .child_span, .info, .debug, .warn, .error, .trace (`src/tracing/facade_dsl.cr`)
- Macros: span!, event!, child_span!, info!, debug!, warn!, error!, trace!, *span! variants (`src/tracing/facade_macros.cr`)
- target: override parameter on span/event DSL methods (`src/tracing/facade_dsl.cr`)
- Tracing::Subscriber: with_default, set_global_default convenience (`src/tracing/subscriber_conv.cr`)

### tracing-subscriber

- Registry: Subscriber impl with mutex-guarded span storage, fiber-local span stack (`src/tracing-subscriber/registry.cr`)
- Registry.default, Registry#init (`src/tracing-subscriber/registry.cr`)
- Layer abstract class: on_event, on_new_span, on_enter, on_exit, on_record, enabled?, max_level_hint (`src/tracing-subscriber/layer.cr`)
- LayerContext with span lookup via subscriber (`src/tracing-subscriber/layer.cr`)
- Layered(S) generic subscriber: Layer + Subscriber composition (`src/tracing-subscriber/layer.cr`)
- Layered#init, #with(layer), #with(nil) (`src/tracing-subscriber/layer.cr`)
- LookupSpan trait + SpanRef with extensions access (`src/tracing-subscriber/lookup_span.cr`)
- Extensions type map: insert, get, replace, remove by type (`src/tracing-subscriber/extensions.cr`)
- LevelFilterLayer: verbosity-based filter as Layer (`src/tracing-subscriber/filter.cr`)
- EnvFilter: directive parsing + subscriber-level filter (`src/tracing-subscriber/env_filter.cr`)
- EnvFilter.from_env(var) convenience (`src/tracing-subscriber/env_filter.cr`)
- Directive parser: `target[span]=level` grammar (`src/tracing-subscriber/env_filter.cr`)
- FilterFn: closure-based filter (`src/tracing-subscriber/filter_fn.cr`)
- Targets: programmatic target-prefix filter with builder pattern (`src/tracing-subscriber/targets.cr`)
- FmtLayer: formatted output to IO with timestamp, level, span, fields (`src/tracing-subscriber/fmt.cr`)
- FmtLayer: compact mode, pretty mode, with_ansi, with_target, with_level (`src/tracing-subscriber/fmt.cr`)
- FmtLayer: with_filter (per-layer level filter), FmtSpan config (`src/tracing-subscriber/fmt.cr`)
- FmtLayer.make_writer: dynamic writer block for file rotation (`src/tracing-subscriber/fmt.cr`)
- Filtered combinator: layer + filter composition (`src/tracing-subscriber/layer.cr`)
- Layer#and_then: compose two layers (`src/tracing-subscriber/layer.cr`)
- NoOpLayer: always-enabled pass-through (`src/tracing-subscriber/layer.cr`)
- Nil-as-Layer: registry.with(nil) support for conditional layers (`src/tracing-subscriber/layer.cr`)
- Tracing.fmt_layer free function (`src/tracing.cr`)

### Dependencies

- lipgloss: terminal styling library for future rich formatting
- perf_tools: development tools for fiber tracing and memory profiling
