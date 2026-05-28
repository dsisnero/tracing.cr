# tracing-core Inventory

Upstream: `vendor/tracing/tracing-core/src/` (pinned at tracing-core-0.1.36)

## Modules

| Module | Upstream File | Crystal File | Status | Notes |
|--------|--------------|-------------|--------|-------|
| Level | `metadata.rs` | `src/tracing/types.cr` | ported | Level enum with inverted comparisons |
| LevelFilter | `metadata.rs` | `src/tracing/types.cr` | ported | Level? wrapper, OFF=nil, Atomic MAX_LEVEL |
| Kind | `metadata.rs` | `src/tracing/types.cr` | ported | Bit flags: EVENT=1, SPAN=2, HINT=4 |
| ParseLevelError | `metadata.rs` | `src/tracing/types.cr` | ported | |
| ParseLevelFilterError | `metadata.rs` | `src/tracing/types.cr` | ported | |
| Identifier | `callsite.rs` | `src/tracing/types.cr` | ported | Opaque pointer wrapper |
| Metadata | `metadata.rs` | `src/tracing/metadata.cr` | ported | name, target, level, fields, kind, file, line, module_path |
| Field | `field.rs` | `src/tracing/field.cr` | ported | Named field with string name |
| FieldSet | `field.rs` | `src/tracing/field.cr` | ported | Ordered field names, callsite reference |
| ValueSet | `field.rs` | `src/tracing/field.cr` | ported | Tagged value storage, typed record methods |
| Visit | `field.rs` | `src/tracing/field.cr` | ported | Abstract visitor trait |
| Interest | `callsite.rs` | `src/tracing/callsite.cr` | ported | NEVER/SOMETIMES/ALWAYS enum |
| Callsite Interface | `callsite.rs` | `src/tracing/callsite.cr` | ported | Abstract callsite trait |
| DefaultCallsite | `callsite.rs` | `src/tracing/callsite.cr` | ported | Ready-made callsite impl |
| Span::Id | `span.rs` | `src/tracing/span.cr` | ported | Non-zero u64 |
| Attributes | `span.rs` | `src/tracing/span.cr` | ported | metadata + values + parent |
| Record | `span.rs` | `src/tracing/span.cr` | ported | ValueSet wrapper |
| Current | `span.rs` | `src/tracing/span.cr` | ported | Current/None/Unknown states |
| Parent | `parent.rs` | `src/tracing/span.cr` | ported | Root/Current/Explicit variants |
| Event | `event.rs` | `src/tracing/event.cr` | ported | metadata + values + parent |
| Subscriber | `subscriber.rs` | `src/tracing/subscriber.cr` | ported | Trait with full interface |
| NoSubscriber | `subscriber.rs` | `src/tracing/subscriber.cr` | ported | No-op subscriber |
| Dispatch | `dispatcher.rs` | `src/tracing/dispatcher.cr` | partial | Global default dispatch, thread-local not yet |
| Callsite registry | `callsite.rs` dispatchers | - | missing | Global callsite list & interest cache |
| Lazy | `lazy.rs` | - | missing | no_std Lazy (not needed for Crystal's std) |
| Spin/Sync | `spin/`, `sync.rs` | - | missing | no_std mutex/once (not needed for Crystal's std) |

## Public API Surface

- [x] `Level`, `LevelFilter` - verbosity levels with inverted comparisons
- [x] `Kind` - Span/Event/Hint bit flags
- [x] `Metadata` - span/event metadata struct
- [x] `Field`, `FieldSet`, `ValueSet`, `Visit` - structured key-value data
- [x] `Span::Id`, `Attributes`, `Record`, `Current` - span types
- [x] `Parent` - Root/Current/Explicit parent
- [x] `Event` - event type
- [x] `Callsite::Identifier`, `Interest`, `Interface`, `DefaultCallsite` - callsite system
- [x] `Subscriber` trait - full subscriber interface
- [x] `NoSubscriber` - no-op subscriber
- [ ] `Dispatch` thread-local support (global default only)
- [ ] Callsite registry and interest cache
- [ ] `set_global_default`, `get_default`, `get_current` full dispatch chain
