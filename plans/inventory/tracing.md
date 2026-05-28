# tracing Inventory

Upstream: `vendor/tracing/tracing/src/` (pinned at tracing-0.1.44)

Depends on: tracing-core

## Modules

| Module | Upstream File | Status | Notes |
|--------|--------------|--------|-------|
| Span macros | `macros.rs` | Not started | span!, event!, trace!, debug!, info!, warn!, error! macros |
| Span | `span.rs` | Not started | Span handle, Span::enter/exit |
| Event | (in macros) | Not started | Event dispatch |
| Subscriber | `subscriber.rs` | Not started | Subscriber extension, with_default |
| Dispatcher | `dispatcher.rs` | Not started | Dispatcher accessors |
| Instrument | `instrument.rs` | Not started | Instrument trait |
| Field | `field.rs` | Not started | ValueSet, field recording |
| LevelFilter | `level_filters.rs` | Not started | LevelFilter, verbosity helpers |
| lib | `lib.rs` | Not started | Crate root, re-exports |

## Public API Surface

- `tracing::span!`, `tracing::event!`
- `tracing::trace!`, `tracing::debug!`, `tracing::info!`, `tracing::warn!`, `tracing::error!`
- `tracing::Span` handle
- `tracing::Instrument` trait
- `tracing::Level` / `tracing::LevelFilter`
- `tracing::dispatcher`, `tracing::subscriber`, `tracing::field` modules
- `#[instrument]` attribute (macro)

## Dependencies on tracing-core

- `Span` wraps `tracing_core::Span`
- `Event` wraps `tracing_core::Event`
- `Dispatcher` wraps `tracing_core::Dispatch`
- Macros generate `tracing_core::Metadata` and call into core dispatcher
