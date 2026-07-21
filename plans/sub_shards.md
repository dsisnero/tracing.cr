# Sub-Shard Porting Plan

Survey of all upstream `tokio-rs/tracing` sub-crates with Crystal port
feasibility, effort, and priority ranking.

## Already Ported

| Crate | Version | Status |
|-------|---------|--------|
| tracing-core | 0.1.36 | Complete |
| tracing | 0.1.44 | Complete |
| tracing-subscriber | 0.3.23 | Complete |

## Vendored External Crate

| Crate | Version | Source | Notes |
|-------|---------|--------|-------|
| tracing-chrome | 0.7.2 | `vendor/tracing-chrome/` | Separate ecosystem crate for Chrome / Perfetto trace-event JSON output. Vendored as a standalone submodule, not part of `tokio-rs/tracing`. |

## Ranking

### Tier 1 — High Priority

These crates are generally useful and have clear Crystal equivalents.

| Rank | Crate | Description | Crystal Effort | Rationale |
|------|-------|-------------|----------------|-----------|
| 1 | **tracing-appender** | Non-blocking writer thread + `RollingFileAppender` (time/size-based rotation) | Low | Crystal has `Channel`, `spawn`, `File`. No external deps. The non-blocking pattern is directly portable. The rolling file appender is universally useful for production logging. |
| 2 | **tracing-log** | Bridge between `Log` records and tracing events | Low | Crystal's `Log` module is analogous to Rust's `log` crate. A subscriber that forwards `Log` records to tracing events enables gradual migration. Crystal's `Log.setup` / `Log.builder` pattern maps cleanly. |
| 3 | **tracing-macros** | `trace_dbg!` / `dbg!` macros — emit tracing events with file:line | Very Low | Single macro file (`macros.rs`, 58 lines). Expands `std::dbg!` + `tracing::event!`. Crystal equivalent: a macro that wraps `pp` output + `info!` call. Trivial to port. |

### Tier 2 — Medium Priority

Useful but more niche, or requires adaptation for Crystal.

| Rank | Crate | Description | Crystal Effort | Rationale |
|------|-------|-------------|----------------|-----------|
| 4 | **tracing-mock** | `MockSubscriber` + `expect!` / `with_span` / `check_span` for testing | Medium | Useful for testing subscriber behavior. Requires an expectation builder pattern. Crystal can port this cleanly with blocks and matchers. The `#[track_caller]` equivalent doesn't exist in Crystal but `caller` macro support could work. |
| 5 | **tracing-serde** | Serialize tracing types via `serde` | Medium | Crystal has `JSON::Serializable` and `YAML::Serializable`. Porting the `Serialize` trait implementations for `Id`, `Metadata`, `FieldSet`, etc. to Crystal's serialization framework. Requires choosing JSON vs. generic serialization. Add as `tracing-json` shard? |
| 6 | **tracing-error** | Enrich errors with span context, format spans in error display | Medium | Crystal exception handling differs from Rust's `Result`. The `InstrumentError` / `InstrumentResult` traits wrap errors with span data. Could be adapted for Crystal exceptions with a `TracedError` wrapper that captures the current span context. |
| 7 | **tracing-flame** | Flamegraph generation from span timings (folded stack format) | Medium | Ports `FlameLayer` that records enter/exit timestamps and writes folded stack format. No Crystal flamegraph renderer needed — output is consumed by external tools (`inferno`, `flamegraph.pl`). Pure file I/O + timestamps. |

### Tier 3 — Low Priority

Rust-specific, niche, or blocked by ecosystem gaps.

| Rank | Crate | Description | Crystal Effort | Rationale |
|------|-------|-------------|----------------|-----------|
| 8 | **tracing-attributes** | `#[instrument]` proc macro attribute | High | Rust proc macros have no Crystal equivalent. Crystal macros CAN generate wrapper code, but can't introspect function signatures the same way. Could implement as a manual `instrument(name)` call or a macro that wraps the method body. Limited value vs. boilerplate `span.in_scope { ... }`. |
| 9 | **tracing-futures** | `Instrument` trait + `Instrumented` / `WithDispatch` futures | Low | Rust async ≠ Crystal fibers. Crystal doesn't have `Future` trait, `Poll`, or `Pin`. The `Instrument` pattern for fibers is just `span.in_scope { ... }` which already works. Minimal value to port. |
| 10 | **tracing-journald** | systemd journal logging layer | Low | Linux-specific. Crystal would need libsystemd FFI bindings. Extremely niche for Crystal's user base (primarily macOS/Linux desktop, not systemd services). |
| 11 | **tracing-tower** | tower middleware compatibility | Very Low | tower is a Rust-specific HTTP middleware framework. No Crystal equivalent. Skip entirely. |
| 12 | **tracing-test** | `PollN` test helper for futures | Very Low | Rust async test utilities. Crystal fibers don't need `PollN`. Skip entirely. |

## Implementation Notes

### tracing-appender

```
src/tracing-appender/
├── non_blocking.cr    # NonBlocking writer: Channel + spawn(fiber) pattern
├── rolling.cr         # RollingFileAppender: hourly/daily/never rotation
└── worker.cr          # MsgBuf, WorkerGuard
```

Key types: `NonBlockingBuilder`, `RollingFileAppender`, `Rotation`.
Crystal patterns: `Channel(T)` for bounded message passing, `spawn` for worker fiber.
Upstream: `vendor/tracing/tracing-appender/src/` (~4 files, ~800 lines).

### tracing-log

```
src/tracing-log/
└── log_layer.cr       # LogTracer: wraps Log::Backend, forwards to tracing
```

Key concept: intercept `Log` records and emit them as `tracing` events.
Crystal has `Log.setup` with `Log::Backend` — analogous to Rust's `log::Log`.
The `LogTracer` becomes a `Log::Backend` that calls `Tracing.event(...)`.
Upstream: `vendor/tracing/tracing-log/src/` (~2 files, ~300 lines).

### tracing-macros

Single file port:
```crystal
# Expands to: info!("message", key = value, file: __FILE__, line: __LINE__)
macro trace_dbg!(expr)
  info!("trace_dbg", file: {{ __FILE__ }}, line: {{ __LINE__ }}, value: {{ expr }})
end
```
Upstream: `vendor/tracing/tracing-macros/src/lib.rs` (58 lines).

## Porting Order

```
1. tracing-appender  → non-blocking writers + file rotation
2. tracing-log       → Crystal Log integration
3. tracing-macros    → trace_dbg! utility macro
4. tracing-mock      → testing utilities
5. tracing-serde     → JSON serialization
6. tracing-error     → error enrichment
7. tracing-flame     → flamegraph generation
8. tracing-attributes → defer (proc macro equivalent)
9-12.                → skip (Rust-specific)
```
