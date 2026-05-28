# tracing-subscriber Inventory

Upstream: `vendor/tracing/tracing-subscriber/src/` (pinned at tracing-subscriber-0.3.23)

Depends on: tracing-core, tracing

## Modules

| Module | Upstream File | Status | Notes |
|--------|--------------|--------|-------|
| Layer | `layer/mod.rs`, `layer/layered.rs`, `layer/context.rs` | Not started | Layer trait, Layered, Context |
| Registry | `registry/mod.rs`, `registry/sharded.rs`, `registry/stack.rs`, `registry/extensions.rs` | Not started | Registry subscriber |
| FmtLayer | `fmt/fmt_layer.rs` | Not started | Formatted output layer |
| Fmt | `fmt/mod.rs` | Not started | fmt module root |
| Format | `fmt/format/mod.rs`, `fmt/format/json.rs`, `fmt/format/pretty.rs`, `fmt/format/escape.rs` | Not started | Event formatting |
| Time | `fmt/time/mod.rs`, `fmt/time/datetime.rs`, `fmt/time/chrono_crate.rs`, `fmt/time/time_crate.rs` | Not started | Timestamp formatting |
| Writer | `fmt/writer.rs` | Not started | MakeWriter trait |
| Filter | `filter/mod.rs` | Not started | Filter module root |
| EnvFilter | `filter/env/mod.rs`, `filter/env/builder.rs`, `filter/env/directive.rs`, `filter/env/field.rs` | Not started | Env-based filter |
| Directives | `filter/directive.rs` | Not started | Parse directives |
| LevelFilter | `filter/level.rs` | Not started | Level-based filter |
| TargetFilter | `filter/targets.rs` | Not started | Target-based filter |
| FilterFn | `filter/filter_fn.rs` | Not started | Function-based filter |
| LayerFilters | `filter/layer_filters/mod.rs`, `filter/layer_filters/combinator.rs` | Not started | Per-layer filtering |
| Field (subscriber) | `field/mod.rs`, `field/debug.rs`, `field/display.rs`, `field/delimited.rs` | Not started | Field visitors |
| Reload | `reload.rs` | Not started | Reload handle |
| Util | `util.rs` | Not started | Utilities |
| Sync | `sync.rs` | Not started | Thread safety primitives |
| Macros | `macros.rs` | Not started | Subscriber macros |
| Prelude | `prelude.rs` | Not started | Prelude re-exports |
| lib | `lib.rs` | Not started | Crate root |

## Public API Surface

- `tracing_subscriber::layer::Layer` trait
- `tracing_subscriber::layer::Layered`, `tracing_subscriber::layer::Context`
- `tracing_subscriber::Registry`
- `tracing_subscriber::fmt::SubscriberBuilder`, `tracing_subscriber::fmt::Layer`
- `tracing_subscriber::filter::EnvFilter`, `tracing_subscriber::filter::LevelFilter`
- `tracing_subscriber::filter::Targets`
- `tracing_subscriber::reload::Handle`
- `tracing_subscriber::fmt::format`, `tracing_subscriber::fmt::time`
- `tracing_subscriber::prelude`

## Dependencies on tracing-core / tracing

- Layers implement `Subscriber` + `Layer` traits from tracing-core
- Registry is a `Subscriber` implementation
- Fmt uses `tracing_core::Event`, `tracing_core::Metadata` for formatting
