# Architecture

The tracing framework mirrors upstream [tokio-rs/tracing](https://github.com/tokio-rs/tracing)
across three crates, each implemented in Crystal under `src/`.

## Crate Structure

| Crate | Upstream Source | Crystal Source | Status |
|-------|----------------|----------------|--------|
| tracing-core | `vendor/tracing/tracing-core/src/` | `src/tracing/` | Complete |
| tracing | `vendor/tracing/tracing/src/` | `src/tracing/` (facade files) | Complete |
| tracing-subscriber | `vendor/tracing/tracing-subscriber/src/` | `src/tracing-subscriber/` | Complete |

## tracing-core (`src/tracing/`)

Foundation types and dispatch infrastructure. No macros, no formatting.

| File | Purpose | Key Types |
|------|---------|-----------|
| `types.cr` | Verbosity levels, callsite IDs, kind flags | `Level`, `LevelFilter`, `Kind`, `Callsite::Identifier`, `Interest` |
| `metadata.cr` | Span/event metadata | `Metadata` (name, target, level, fields, kind, source location) |
| `field.cr` | Structured key-value data | `Field`, `FieldSet`, `ValueSet`, `Visit` trait |
| `callsite.cr` | Callsite trait + global registry | `Interface` (trait), `DefaultCallsite`, `Callsites` (lock-free linked list) |
| `span.cr` | Span types + parent | `Span::Id`, `Attributes`, `Record`, `Current`, `Parent` |
| `event.cr` | Event type | `Event` (metadata, values, parent) |
| `subscriber.cr` | Subscriber trait | `Subscriber` (abstract trait), `NoSubscriber` |
| `dispatcher.cr` | Global + fiber-local dispatch | `Dispatch`, `Dispatchers::Manager` |

### Data Flow

```
span!(level, name, fields)                    # user code
  → Tracing.span(level, name, **fields)       # facade_dsl.cr
    → metadata = Metadata.new(...)             # metadata.cr
    → dispatch = Dispatch.current              # dispatcher.cr
    → dispatch.enabled(metadata)               # subscriber-level filter check
    → dispatch.new_span(attrs)                 # Layered → Registry.new_span
      → Registry stores SpanData in @spans    # registry.cr
    → Span.new(inner, meta)                    # facade_span.cr
    → span.enter                               # subscriber.enter(id)
      → Registry pushes to fiber stack        # registry.cr
      → span.exit (via Entered guard)          # subscriber.exit(id)
```

## tracing facade (`src/tracing/`)

User-facing API: Span handle, DSL methods, macros.

| File | Purpose |
|------|---------|
| `facade_span.cr` | `Span` handle with enter/exit/in_scope lifecycle |
| `facade_dsl.cr` | `Tracing.span`, `.event`, `.info`, `.debug`, `.warn`, `.error`, `.trace` |
| `facade_macros.cr` | `span!`, `event!`, `info!`, `debug_span!`, etc. |
| `subscriber_conv.cr` | `Tracing::Subscriber.with_default`, `.set_global_default` |

## tracing-subscriber (`src/tracing-subscriber/`)

Subscriber implementations: storage, layers, filtering, formatting.

### Registry (`registry.cr`)

`Tracing::Registry` implements `Subscriber` and stores span data.

```crystal
@spans : Hash(UInt64, SpanData)          # span_id → stored data
@current_span_ids : Hash(UInt64, Array)  # fiber_id → span stack
@next_id : Atomic(UInt64)                # span ID counter
```

`SpanData` struct: `id`, `name`, `metadata`, `parent`, `extensions`.

### Layer System (`layer.cr`, `lookup_span.cr`)

| Type | Purpose |
|------|---------|
| `Layer` (abstract class) | Observer hooks: on_event, on_new_span, on_enter, on_exit, on_record |
| `LayerContext` | Passed to hooks; provides `span(id)`, `event_span(event)` via subscriber |
| `Layered(S)` | Generic subscriber composing a `Layer` with an inner `Subscriber` |
| `LookupSpan` (trait) | `span_data(id)`, `span(id)` for querying stored span data |
| `SpanRef` | Reference to stored span data with `extensions` access |
| `NoOpLayer` | Always-enabled pass-through |
| `Filtered` | Composes two layers: inner for recording, outer for filtering |

### Layer Lifecycle

```
Registry                     # @inner of innermost Layered
  .with(FilterLayer)         # @layer = filter, @inner = Registry
    .with(FmtLayer)          # @layer = fmt, @inner = Layered[filter, Registry]
```

Outermost layer's `enabled?`, `register_callsite`, `max_level_hint` gate the
entire subscriber. Inner subscriber always receives events for lifecycle tracking.
Layer hooks are called only when the layer's `enabled?` returns true.

### Filters (`filter.cr`, `env_filter.cr`, `filter_fn.cr`, `targets.cr`)

| Type | Purpose | Configuration |
|------|---------|---------------|
| `LevelFilterLayer` | Verbosity threshold | `LevelFilterLayer.new(LevelFilter::INFO)` |
| `EnvFilter` | Env-var directive parsing | `EnvFilter.new("info,my_crate=debug")` |
| `FilterFn` | Closure-based | `FilterFn.new { \|meta\| meta.level <= Level::WARN }` |
| `Targets` | Programmatic target matching | `Targets.new.with_target("crate", Level::INFO)` |

`Directive` struct parses `target[span_name]=level` grammar.

### Formatted Output (`fmt.cr`)

`FmtLayer` writes events/spans to an `IO` (default `STDOUT`).

Modes:
- **Default**: timestamped single-line
- **Compact** (`.compact`): single-line, no timestamps
- **Pretty** (`.pretty`): multi-line with indented fields

Builder options: `.with_target`, `.with_level`, `.with_filter`, `.with_ansi`,
`.with_span_events`, `.make_writer`

### Extensions (`extensions.cr`)

Per-span type-erased storage: `Extensions` with `insert(T)`, `get(T)`, `replace(T)`, `remove(T)`.
Stored via heap-allocated `Pointer(T)` keyed by type name string.
`ExtensionsMut` provides mutable access wrapper.
