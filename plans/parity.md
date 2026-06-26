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

**Total: 269 specs across 13 sub-crates.**

> `✓` marks feature-level parity for the shipped surface. Outstanding work is
> tracked in [Remaining for Parity](#remaining-for-parity).

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
- [x] FmtLayer.with_thread_ids, .with_thread_names (fiber id/name)
- [x] FmtLayer.with_timer (FormatTime: SystemTime, Uptime)
- [x] DateTime (musl-based ISO 8601, full i64 range)
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
- [x] Targets.parse (FromStr) — `target=level` directives, numeric/uppercase/mixed levels
- [x] Targets#to_s (Display) + parse round-trip, #default_level (Option), #iter, #would_enable
- [x] Reload (reload::Layer) + Handle — runtime-swappable inner layer (reload/modify/with_current/handle)
- [x] SpanRef#scope / #from_root / #parent — ancestor iteration (contextual parents resolved at new_span)
- [x] FilterExt combinators — Layer#and / #or / #not (And/Or/Not filter combinators)
- [x] EnvFilter span-name matching (target[span]=level)
- [x] Dispatch.has_been_set?, clone_span, drop_span, try_close
- [x] Span#or_current — return self or current span
- [x] FmtLayer#without_time — disables timestamp output
- [x] FmtLayer#with_test_writer — writes via `TestWriter` (STDOUT, captured by `crystal spec`)
- [x] FmtWriter::TestWriter — IO subclass for unit-test output capture
- [x] FmtWriter::MakeWriter — abstract class with make_writer(meta) → IO
- [x] FmtWriter::NoopWriter — /dev/null IO that discards writes
- [x] FmtWriter::WithMaxLevel — level-based writer combinator
- [x] FmtLayer#with_make_writer — accepts MakeWriter objects
- [x] FmtWriter::WithMinLevel — min-level writer combinator
- [x] FmtWriter::WithFilter — metadata-predicate writer combinator
- [x] FmtWriter::Tee + TeeWriter — fan-out to two writers (`.and`)
- [x] FmtWriter::OrElse — fallback to second writer when first returns NoopWriter (`.or_else`)
- [x] FmtSubscriberBuilder — builder pattern with delegate methods + `finish`/`init`/`try_init`
- [x] Tracing.fmt — entry point returning a default-configured `FmtSubscriberBuilder`
- [x] FmtLayer#flatten_event / #with_current_span — JSON format options matching upstream defaults
- [x] FmtSubscriberBuilder#with_filter_reloading + #reload_handle — runtime filter swapping via Reload
- [x] FmtFormat::Writer — IO wrapper with ANSI escape tracking
- [x] FmtFormat::FormatFields — abstract class for field formatting
- [x] FmtFormat::FormatEvent — abstract class for event formatting
- [x] FmtFormat::DefaultFields — Field::Visit-based field formatter; FmtLayer delegates field formatting

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
- [x] `RollingFileAppender::Builder` — filename_prefix/suffix, max_log_files
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

(Remaining OTel items — Tracer integration, Context propagation, Metrics — are
tracked under [Remaining for Parity](#remaining-for-parity).)

## Remaining for Parity

Genuine feature gaps from the `plans/inventory/` audit. Most remaining inventory
rows are auto-generated test stubs or getters already covered by shipped
features; the items below are the real gaps. The inventory is under-reconciled,
so **verify each against `src/` before starting**.

### tracing-subscriber — `fmt` (largest gap)

- [x] `FormatEvent` / `FormatFields` abstract classes + `Writer` struct (pluggable formatting foundation)
- [x] `FmtFormat::DefaultFields` — default field formatter (key=value pairs); wired into `FmtLayer`
- [ ] Wire `FmtLayer` to delegate to `FormatEvent` implementation (next step)
- [ ] Field formatters: `DefaultFields`, `DefaultVisitor`, `FormattedFields`
- [ ] Field-visitor infra: `MakeVisitor`, `VisitFmt`, `VisitOutput`, `RecordFields`
- [x] `Json` options: `flatten_event`, `with_current_span` (span list deferred — needs `FormattedFields` infra)
- [ ] `JsonFields` / `JsonVisitor` — rich span objects in JSON (needs `FormattedFields`)
- [x] `FmtLayer#with_thread_ids`, `#with_thread_names`
- [x] `FmtLayer#without_time`, `#with_test_writer`
- [x] `TestWriter` — output-capture writer for unit tests
- [x] `MakeWriter` abstract class + `MakeWriter::Proc` + `NoopWriter`
- [x] `MakeWriterExt` combinators: `WithMaxLevel`, `WithMinLevel`, `WithFilter`, `Tee` (`.and`), `OrElse` (`.or_else`)
- [x] `fmt::Subscriber` builder — `Tracing.fmt` → `FmtSubscriberBuilder` with `finish`/`init`/`try_init`
- [x] `FmtSubscriberBuilder#with_filter_reloading` + `#reload_handle` — runtime filter swapping

### tracing-subscriber — registry / filter / util

- [x] `SpanRef#scope` / `#from_root` / `#parent` (`Scope` ancestor iteration; registry resolves contextual parents at `new_span`)
- [ ] `SubscriberInitExt#try_init`
- [ ] `EnvFilter` field-value directives `target[span{field=val}]=level` (verify; basic level/target/span-name done)
- [x] `FilterExt` combinators `Layer#and` / `#or` / `#not` (`.boxed` is N/A — Crystal uses runtime polymorphism)

### tracing-appender

- [x] `RollingFileAppender::Builder` — `max_log_files`, `filename_suffix`, `filename_prefix`
- [ ] `NonBlocking.lossy` real non-blocking send (currently placeholder — see Divergences)

### tracing — instrument / futures

- [ ] `Instrument` / `WithSubscriber` for fibers (async instrumentation; partially covered by `tracing/concurrency`)

### Sub-crates not started (scope decisions)

- [ ] tracing-error: backtrace formatting + `ExtractSpanTrace` / `InstrumentError` / `InstrumentResult`
- [ ] tracing-log: `AsLog` / `AsTrace` / `NormalizeEvent` / `interest_cache`, `LogTracer::builder`
- [ ] tracing-futures: `Instrument` / `WithSubscriber` traits
- [ ] tracing-serde: standalone `AsSerde` / `AsMap` traits (likely **N/A** — Crystal uses `JSON.build`)
- [ ] tracing-journald: systemd journal sink (Linux-only — decide **skip**)
- [ ] tracing-tower: tower middleware (Rust-ecosystem-specific — decide **skip**)

### tracing-opentelemetry (blocked / deferred)

- [ ] Tracer integration (blocked — needs dynamic dispatch)
- [ ] Context propagation (blocked — needs OTel Context API)
- [ ] Metrics (deferred)

### Housekeeping

- [ ] Reconcile `plans/inventory/` — mark already-ported symbols so `missing` reflects real gaps

## Divergences

Intentional differences from upstream. Behavioral divergences are also noted in
the relevant source files; omitted symbols are marked `skipped` in
`plans/inventory/`.

### tracing-subscriber — `filter::Targets`

- `#default_level` returns `LevelFilter?` (matches upstream `Option<LevelFilter>`):
  `nil` means "unset" and behaves as `OFF` when filtering. This replaces the
  prior Crystal default of `TRACE` (enable-all); an unset default now disables
  unmatched targets, matching upstream.
- `#iter` returns a lazy `Iterator({String, LevelFilter})` (Crystal's analog of
  Rust's `Iter`). Rust's separate `Iter` (borrowing) and `IntoIter` (owning)
  structs collapse into this single `Iterator`.
- `size_of_filters` (Rust `size_of_val`) is not applicable to Crystal.

### tracing-subscriber — `reload`

- The upstream global callsite interest-cache recompute on reload
  (`callsite::rebuild_interest_cache`) is omitted. The port's
  `Dispatch.with_default` is fiber-local and does not register a global
  dispatcher, and rebuilding with no registered dispatcher would mark every
  callsite uninterested. `Reload` therefore only swaps the inner layer; global
  interest management remains the dispatcher's responsibility.
- The Rust weak-reference / lock-poisoning surface (`clone_current`,
  `is_dropped`, `is_poisoned`, `Error`) has no Crystal equivalent and is omitted.

### tracing-subscriber — `registry`

- `SpanRef#scope` returns a lazy `Scope` iterator and `#from_root` returns a
  plain `Iterator(SpanRef)`; Rust's separate `ScopeFromRoot` struct is not
  needed (same pattern as `Targets#iter`).

### tracing-appender

- `NonBlocking.lossy` is a placeholder: Crystal's `Channel` supports only
  blocking send, so non-lossy (backpressure) is the actual behavior until a
  non-blocking channel send is available.
- `RollingFileAppender`'s `max_log_files` prunes by file **modification** time;
  upstream orders by creation time (with a filename-date fallback), which
  `File::Info` does not expose on Crystal.

### tracing-subscriber — `fmt` thread info

- `FmtLayer#with_thread_ids` / `#with_thread_names` show the current **fiber**'s
  object id / name — Crystal has no OS-thread-per-task model, so threads map to
  fibers. `with_thread_ids` prints the fiber `object_id`, not an OS thread id.

### tracing-subscriber — `fmt::time`

- `chrono` / `time` crate formatters are not ported (no Crystal equivalent);
  `SystemTime` / `Uptime` / a musl-based `DateTime` cover the built-in timers.

## Quality Gates

```bash
crystal tool format --check src spec
ameba src spec
crystal spec   # 269 examples
```
