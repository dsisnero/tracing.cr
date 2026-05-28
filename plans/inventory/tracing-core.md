# tracing-core Inventory

Upstream: `vendor/tracing/tracing-core/src/` (pinned at tracing-core-0.1.36)

## Modules

| Module | Upstream File | Crystal File | Status | Crystal Name Changes |
|--------|--------------|-------------|--------|---------------------|
| Level | `metadata.rs` | `src/tracing/types.cr` | ported | - |
| LevelFilter | `metadata.rs` | `src/tracing/types.cr` | ported | `set_max()` ↦ `max=` |
| Kind | `metadata.rs` | `src/tracing/types.cr` | ported | `is_event()` ↦ `event?`, `is_span()` ↦ `span?`, `is_hint()` ↦ `hint?` |
| ParseLevelError | `metadata.rs` | `src/tracing/types.cr` | ported | - |
| ParseLevelFilterError | `metadata.rs` | `src/tracing/types.cr` | ported | - |
| Identifier | `callsite.rs` | `src/tracing/types.cr` | ported | - |
| Metadata | `metadata.rs` | `src/tracing/metadata.cr` | ported | `is_event()` ↦ `event?`, `is_span()` ↦ `span?` |
| Field | `field.rs` | `src/tracing/field.cr` | ported | - |
| FieldSet | `field.rs` | `src/tracing/field.cr` | ported | - |
| ValueSet | `field.rs` | `src/tracing/field.cr` | ported | `is_empty()` ↦ `empty?` |
| Visit | `field.rs` | `src/tracing/field.cr` | ported | - |
| Interest | `callsite.rs` | `src/tracing/callsite.cr` | ported | - |
| Callsite Interface | `callsite.rs` | `src/tracing/callsite.cr` | ported | `set_interest()` ↦ `interest=` |
| DefaultCallsite | `callsite.rs` | `src/tracing/callsite.cr` | ported | `set_interest()` ↦ `interest=` |
| Span::Id | `span.rs` | `src/tracing/span.cr` | ported | - |
| Attributes | `span.rs` | `src/tracing/span.cr` | ported | `is_root()` ↦ `root?`, `is_contextual()` ↦ `contextual?` |
| Record | `span.rs` | `src/tracing/span.cr` | ported | - |
| Current | `span.rs` | `src/tracing/span.cr` | ported | - |
| Parent | `parent.rs` | `src/tracing/span.cr` | ported | - |
| Event | `event.rs` | `src/tracing/event.cr` | ported | `is_root()` ↦ `root?`, `is_contextual()` ↦ `contextual?` |
| Subscriber | `subscriber.rs` | `src/tracing/subscriber.cr` | ported | - |
| NoSubscriber | `subscriber.rs` | `src/tracing/subscriber.cr` | ported | - |
| Dispatch | `dispatcher.rs` | `src/tracing/dispatcher.cr` | partial | `set_global_default()` ↦ `global_default=`, `get_default()` ↦ `default` |
| Callsite registry | `callsite.rs` dispatchers | - | missing | - |
| Lazy | `lazy.rs` | - | missing | (not needed with Crystal std) |
| Spin/Sync | `spin/`, `sync.rs` | - | missing | (not needed with Crystal std) |

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
- [ ] `identify_callsite!` / `metadata!` macros

## Naming Convention Map

Crystal idioms vs upstream Rust:

| Rust | Crystal | Reason |
|------|---------|--------|
| `is_event()` | `event?` | Crystal predicate convention drops `is_` prefix |
| `is_span()` | `span?` | Same |
| `is_hint()` | `hint?` | Same |
| `is_root()` | `root?` | Same |
| `is_contextual()` | `contextual?` | Same |
| `is_empty()` | `empty?` | Same |
| `set_interest(x)` | `interest = x` | Crystal setter convention uses `=` suffix |
| `set_max(x)` | `max = x` | Same |
| `set_global_default(x)` | `global_default = x` | Same |
| `get_default()` | `default` | Crystal getter convention drops `get_` prefix |
