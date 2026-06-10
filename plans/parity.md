# Porting Parity Status

Upstream: **tokio-rs/tracing** pinned at `tracing-0.1.44` (commit `2d55f6f`)

## Summary

| Crate | Version | Status | Specs |
|-------|---------|--------|-------|
| tracing-core | 0.1.36 | ✓ | 12 features |
| tracing | 0.1.44 | ✓ | 10 features |
| tracing-subscriber | 0.3.23 | ✓ | 23 features |
| tracing-macros | 0.1.0 | ✓ | `trace_dbg!` |
| tracing-log | 0.2.0 | ✓ | `LogTracer` |
| tracing-appender | 0.2.0 | ✓ | NonBlocking + Rolling |
| tracing-mock | 0.1.0 | ✓ | MockSubscriber |
| tracing-error | 0.1.0 | ✓ | SpanTrace |
| tracing-flame | 0.1.0 | ✓ | FlameLayer |
| tracing-attributes | 0.1.0 | ✓ | @[Instrument] |
| tracing-serde | 0.1.0 | ✓ | JSON mode |
| tracing-opentelemetry | 0.33.0 | ✓ | 11 features |
| tracing/concurrency | 0.2.5 | ✓ | Fiber + Channel |

**Total: 166 specs across 13 sub-crates.**

## Done (core)

### tracing-core ✓

- [x] Level, LevelFilter, Kind
- [x] Metadata (name, target, level, fields, kind, source location)
- [x] Field, FieldSet, ValueSet, Visit trait
- [x] Callsite::Identifier, Interest, Interface, DefaultCallsite
- [x] Callsite registry (lock-free linked list, interest caching)
- [x] Span::Id, Attributes, Record, Current
- [x] Parent (Root, Current, Explicit)
- [x] Event (metadata, values, parent)
- [x] Subscriber trait + NoSubscriber
- [x] Dispatch (global, fiber-local with_default, interest rebuild)
- [x] Dispatchers manager (multi-dispatch)
- [x] Level/LevelFilter bi-directional comparisons

### tracing ✓

- [x] Span handle (enter/exit/in_scope, disabled?)
- [x] Span::current, Span::none, Span#or_current
- [x] Entered/EnteredSpan guards
- [x] DSL: Tracing.span, .event, .info, .debug, .warn, .error, .trace
- [x] target: override on span/event
- [x] Macros: span!, event!, child_span!, info!, debug!, warn!, error!, trace!, *span!
- [x] STATIC_MAX_LEVEL compile-time -D flags
- [x] Span#record(**fields), Span#follows_from
- [x] Tracing::Subscriber (with_default, set_global_default)
- [x] Tracing.fmt_layer free function
- [x] Tracing.instrument block wrapper + @[Instrument] annotation

### tracing-subscriber ✓

- [x] Registry (span storage, fiber-local span stack)
- [x] Registry.default, Registry#init
- [x] Layer abstract class
- [x] LayerContext + LookupSpan + SpanRef
- [x] Layered(S) subscriber
- [x] Layered#with(layer), #with(nil), #init
- [x] Extensions type map + ExtensionsMut
- [x] LevelFilterLayer
- [x] EnvFilter (directive parsing + from_env)
- [x] FilterFn (closure-based)
- [x] Targets (programmatic target-prefix)
- [x] Filtered combinator + Layer#and_then
- [x] NoOpLayer + Nil-as-Layer
- [x] FmtLayer (compact, pretty, JSON, ANSI)
- [x] FmtLayer.with_target, .with_level, .with_span_events
- [x] FmtLayer.make_writer (dynamic writer block)
- [x] FmtSpan @[Flags] enum
- [x] MockSubscriber
- [x] SpanTrace
- [x] LogTracer (Crystal Log bridge)
- [x] NonBlocking + WorkerGuard
- [x] NonBlocking.lossy parameter (placeholder)
- [x] RollingFileAppender + Rotation enum
- [x] FlameLayer + folded stack output
- [x] Registry#clone_span + try_close (span lifecycle)
- [x] Targets.with_targets(Enumerable) — batch config
- [x] EnvFilter span-name matching (target[span]=level)
- [x] Dispatch.has_been_set?, clone_span, drop_span, try_close
- [x] Span#or_current — return self or current span

## Done (sub-crates)

### tracing-macros ✓
- [x] `trace_dbg!` macro

### tracing-log ✓
- [x] `LogTracer` — Crystal Log::Backend bridge
- [x] Sync/async dispatch modes

### tracing-appender ✓
- [x] `NonBlocking` — Channel + spawn fiber worker
- [x] `WorkerGuard` — ensures flush on close
- [x] `RollingFileAppender` — daily/hourly/minutely/never
- [x] `Rotation` enum

### tracing-mock ✓
- [x] `MockSubscriber` — expect/assert pattern

### tracing-error ✓
- [x] `SpanTrace` — capture span context

### tracing-flame ✓
- [x] `FlameLayer` — folded stack output
- [x] FlameGuard

### tracing-attributes ✓
- [x] @[Instrument] annotation
- [x] Tracing.instrument block wrapper

### tracing-serde ✓
- [x] FmtLayer JSON mode
- [x] Typed JSON (int, bool, float)

### tracing/concurrency ✓
- [x] Concurrency.spawn (span propagation)
- [x] Concurrency.spawn_with_span (specific span)
- [x] Concurrency.with_subscriber (specific subscriber)
- [x] TracedChannel(T) — traced send/receive
- [x] Fiber extension — Fiber.spawn_traced
- [x] Channel extension — Channel#traced

### tracing-opentelemetry ✓ (in progress)

- [x] OpenTelemetryLayer
- [x] Span kind mapping (otel.kind → SpanKind)
- [x] Span status mapping (otel.status_code → StatusCode)
- [x] Dynamic span name (otel.name)
- [x] Error event → exception detection
- [x] with_level, with_target, with_location, with_threads
- [ ] Tracer integration (blocked — needs dynamic dispatch)
- [ ] Context propagation (blocked — needs OTel Context API)
- [ ] Metrics (deferred)

## Quality Gates

```bash
crystal tool format --check src spec
ameba src spec
crystal spec   # 160 examples
```
