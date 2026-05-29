# Porting Parity Status

Upstream: **tokio-rs/tracing** pinned at `tracing-0.1.44` (commit `2d55f6f`)

| Crate | Upstream Version | Status | Manifests |
|-------|-----------------|--------|-----------|
| tracing-core | 0.1.36 | ✓ Complete | `plans/inventory/rust_port_inventory.tsv` |
| tracing | 0.1.44 | ✓ Complete | — |
| tracing-subscriber | 0.3.23 | ✓ Complete | — |
| tracing-macros | 0.1.0 | ✓ Complete | — |
| tracing-log | 0.2.0 | ✓ Complete | `plans/inventory/tracing_log_port_inventory.tsv` |
| tracing-appender | 0.2.0 | ✓ Complete | `plans/inventory/tracing_appender_port_inventory.tsv` |
| tracing-mock | 0.1.0 | ✓ Complete | — |
| tracing-error | 0.1.0 | ✓ Complete | — |
| tracing-flame | 0.1.0 | ✓ Complete | — |
| tracing-attributes | 0.1.0 | ✓ Complete | — |
| tracing-serde | 0.1.0 | Not started | — |
| tracing-opentelemetry | 0.33.0 | Not started | `plans/inventory/tracing_opentelemetry_port_inventory.tsv` (69 items) |

## tracing-core ✓

- [x] Level, LevelFilter (inverted comparisons), Kind
- [x] Metadata (name, target, level, fields, kind, source location)
- [x] Field, FieldSet, ValueSet, Visit trait
- [x] Callsite::Identifier, Interest, Interface, DefaultCallsite
- [x] Callsite registry (lock-free linked list, CAS registration, interest caching)
- [x] Span::Id, Attributes, Record, Current
- [x] Parent (Root, Current, Explicit)
- [x] Event (metadata, values, parent)
- [x] Subscriber trait + NoSubscriber
- [x] Dispatch (global default, fiber-local with_default, interest rebuild)
- [x] Dispatchers manager (multi-dispatch, callsite rebuild integration)
- [x] Level/LevelFilter bi-directional comparison operators

## tracing ✓

- [x] Span handle (enter/exit/in_scope lifecycle, disabled? detection)
- [x] Entered/EnteredSpan guards (explicit exit, ensure-block cleanup)
- [x] DSL: Tracing.span, .event, .child_span, .info, .debug, .warn, .error, .trace
- [x] target: override parameter on span/event methods
- [x] Macros: span!, event!, child_span!, info!, debug!, warn!, error!, trace!, *span!
- [x] Span#record(**fields) post-creation field recording
- [x] Tracing::Subscriber module (with_default, set_global_default)
- [x] Tracing.fmt_layer free function
- [x] Dispatch.with_default fiber-local scoping

## tracing-subscriber ✓

- [x] Registry (Subscriber impl, span storage, fiber-local span stack, SpanData)
- [x] Registry.default, Registry#init
- [x] Layer abstract class (on_event, on_new_span, on_enter, on_exit, on_record, enabled?, max_level_hint)
- [x] LayerContext (span lookup, event_span) + LookupSpan trait + SpanRef
- [x] Layered(S) generic subscriber (Layer + Subscriber composition)
- [x] Layered#with(layer), #with(nil), #init
- [x] Extensions type map + ExtensionsMut (insert, get, replace, remove by type)
- [x] LevelFilterLayer (verbosity filter as Layer)
- [x] EnvFilter (directive parsing: `target[span]=level`, subscriber-level filter)
- [x] EnvFilter.from_env(var) convenience
- [x] FilterFn (closure-based: `FilterFn.new { |meta| ... }`)
- [x] Targets (programmatic target-prefix filter with builder)
- [x] Filtered combinator + Layer#and_then
- [x] NoOpLayer + Nil-as-Layer support
- [x] FmtLayer: formatted output (timestamp, level, span, fields)
- [x] FmtLayer.compact (single-line, no timestamps)
- [x] FmtLayer.pretty (multi-line with indented fields)
- [x] FmtLayer.with_ansi (level color codes)
- [x] FmtLayer.with_target, .with_level, .with_filter, .with_span_events
- [x] FmtLayer.make_writer (dynamic writer block for file rotation)
- [x] FmtSpan @[Flags] enum (NONE, NEW, ENTER, EXIT, CLOSE, ACTIVE, FULL)
- [x] Span#record(**fields) observed by Layer on_record hook
- [x] LevelFilter.current global max level test

## Tier 1 — Next

### tracing-macros

Upstream: `vendor/tracing/tracing-macros/src/lib.rs` (46 lines)

- [ ] `trace_dbg!` macro — evaluates expr, emits event, returns value
- [ ] `dbg!` macro — like std dbg but emits tracing event with `?value` formatting
- [ ] Level override: `trace_dbg!(level: Level::INFO, expr)`

### tracing-log

Upstream: `vendor/tracing/tracing-log/src/` (34 items in manifest)

- [ ] `LogTracer` — `Log::Backend` that forwards `Log` records to tracing events
- [ ] `InterestCacheConfig` — cache interest decisions for log records
- [ ] `AsLog` trait — convert tracing types to log equivalents
- [ ] Integration: `Log.setup` / `Log.builder` with LogTracer

### tracing-appender

Upstream: `vendor/tracing/tracing-appender/src/` (49 items in manifest)

- [ ] `NonBlocking` — dedicated writer thread with bounded channel
- [ ] `NonBlockingBuilder` — builder API (buffered_lines_limit, lossy, etc.)
- [ ] `RollingFileAppender` — time/size-based file rotation
- [ ] `Rotation` enum — `DAILY`, `HOURLY`, `MINUTELY`, `NEVER`
- [ ] `WorkerGuard` — ensures flush on drop
- [ ] `MsgBuf` — reusable message buffer

## Tier 2 — Medium Priority

### tracing-mock

- [ ] `MockSubscriber` / `MockLayer` — record expected span/event patterns
- [ ] `expect!` — builder for expected events
- [ ] `check_span` / `with_span` — verify span creation and fields

### tracing-serde

- [ ] `Serialize` implementations for tracing-core types (Id, Metadata, etc.)
- [ ] `JsonSubscriber` / `JsonLayer` — JSON output format

### tracing-error

- [ ] `TracedError` wrapper — capture span context on error
- [ ] `InstrumentError` trait — `.in_error(err)` builder

### tracing-flame

- [ ] `FlameLayer` — records enter/exit timestamps
- [ ] Folded stack format output — consumed by flamegraph tools

## Quality Gates

```bash
crystal tool format --check src spec
ameba src spec
crystal spec
```

## Drift Checks

```bash
# Main crate
./scripts/check_port_inventory.sh . plans/inventory/rust_port_inventory.tsv vendor/tracing rust

# Tier 1 sub-crates
./scripts/generate_port_inventory.sh . plans/inventory/tracing_log_port_inventory.tsv vendor/tracing/tracing-log/src rust 1
./scripts/generate_port_inventory.sh . plans/inventory/tracing_appender_port_inventory.tsv vendor/tracing/tracing-appender/src rust 1
```

## tracing-opentelemetry

Upstream: `vendor/tracing-opentelemetry/` (pinned at v0.33.0, commit `1d5422f`)
69 items in manifest.

Bridges `tracing` spans/events to [OpenTelemetry](https://opentelemetry.io)-compatible
distributed tracing systems.

### Core API

- [ ] `OpenTelemetryLayer` — tracing Layer that converts spans/events to OTel
- [ ] `layer()` free function — creates default OpenTelemetryLayer
- [ ] `.with_tracer(tracer)` — configure OTel tracer
- [ ] `PreSampledTracer` — pre-sampled tracer wrapper

### Span Conversion

- [ ] Span ID → OTel `SpanId` mapping
- [ ] Trace ID → OTel `TraceId` (from parent context or generated)
- [ ] Span metadata → OTel span name
- [ ] Span enter/exit → OTel span start/end
- [ ] Span events → OTel span events
- [ ] Span status → OTel status (from `otel.status_code` field)
- [ ] Span kind → OTel `SpanKind` (from `otel.kind` field)
- [ ] Dynamic span name via `otel.name` field

### Context Propagation

- [ ] Extract OTel context from incoming request headers
- [ ] Inject OTel context into outgoing request headers
- [ ] `OtelData` extension stored per-span for context propagation
- [ ] `OpenTelemetrySpanExt` trait — set_parent, context, parent_context

### Error Handling

- [ ] `with_error_events_to_exceptions` — convert error events to OTel exceptions
- [ ] `with_error_events_to_status` — set span status from error events
- [ ] `with_error_fields_to_exceptions` — convert error fields to exceptions
- [ ] `with_error_records_to_exceptions` — convert span error records to exceptions

### Configuration

- [ ] `with_level(Level)` — filter by verbosity level
- [ ] `with_target(bool)` — include/exclude span target
- [ ] `with_location(bool)` — include/exclude span source location
- [ ] `with_threads(bool)` — include/exclude thread info
- [ ] `with_tracked_inactivity(bool)` — track span inactivity duration
- [ ] `with_context_activation(bool)` — activate OTel context on span enter

### Metrics (deferred)

- [ ] `MetricsLayer` — convert tracing events to OTel metrics
- [ ] `ObservableGauge`, `Histogram`, `Counter` metric types
- [ ] Metric attribute conversion from tracing fields

### Dependencies (Crystal)

Requires a Crystal OpenTelemetry shard providing:
- `OpenTelemetry::Trace::Tracer` interface
- `OpenTelemetry::Trace::Span` interface
- `OpenTelemetry::Context` propagation
- `OpenTelemetry::SDK::Trace::TracerProvider`
- Span exporter (e.g., `opentelemetry-stdout`, `opentelemetry-otlp`)

### Notes

This crate depends on an external OpenTelemetry SDK for Crystal. Without a
mature Crystal OTel implementation, this port is blocked. Consider:
1. Porting `opentelemetry-rust` to Crystal first, or
2. Creating a minimal `Tracer` interface that downstream users implement
3. Using the `opentelemetry` Crystal shard if one exists
