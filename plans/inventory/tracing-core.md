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
| Interest | `callsite.rs` | `src/tracing/types.cr` | ported | `is_never()` ↦ `never?`, `is_always()` ↦ `always?` |
| Metadata | `metadata.rs` | `src/tracing/metadata.cr` | ported | `is_event()` ↦ `event?`, `is_span()` ↦ `span?` |
| Field | `field.rs` | `src/tracing/field.cr` | ported | - |
| FieldSet | `field.rs` | `src/tracing/field.cr` | ported | - |
| ValueSet | `field.rs` | `src/tracing/field.cr` | ported | `is_empty()` ↦ `empty?` |
| Visit | `field.rs` | `src/tracing/field.cr` | ported | - |
| Callsite Interface | `callsite.rs` | `src/tracing/callsite.cr` | ported | `set_interest()` ↦ `interest=` |
| DefaultCallsite | `callsite.rs` | `src/tracing/callsite.cr` | ported | atomic interest/registration, lock-free linked list, lazy registration |
| Callsites registry | `callsite.rs` | `src/tracing/callsite.cr` | ported | Lock-free linked list + mutex-guarded vec |
| Span::Id | `span.rs` | `src/tracing/span.cr` | ported | - |
| Attributes | `span.rs` | `src/tracing/span.cr` | ported | `is_root()` ↦ `root?`, `is_contextual()` ↦ `contextual?` |
| Record | `span.rs` | `src/tracing/span.cr` | ported | - |
| Current | `span.rs` | `src/tracing/span.cr` | ported | - |
| Parent | `parent.rs` | `src/tracing/span.cr` | ported | - |
| Event | `event.rs` | `src/tracing/event.cr` | ported | `is_root()` ↦ `root?`, `is_contextual()` ↦ `contextual?` |
| Subscriber | `subscriber.rs` | `src/tracing/subscriber.cr` | ported | - |
| NoSubscriber | `subscriber.rs` | `src/tracing/subscriber.cr` | ported | - |
| Dispatch | `dispatcher.rs` | `src/tracing/dispatcher.cr` | ported | `set_global_default()` ↦ `global_default=`, `get_default()` ↦ `default` |
| Dispatchers manager | `callsite.rs` dispatchers | `src/tracing/dispatcher.cr` | ported | Multi-dispatch management, callsite rebuild integration |
| Rebuilder | `callsite.rs` dispatchers | `src/tracing/dispatcher.cr` | ported | Iterates dispatchers for interest rebuilding |
| Lazy | `lazy.rs` | - | missing | (not needed with Crystal std) |
| Spin/Sync | `spin/`, `sync.rs` | - | missing | (not needed with Crystal std) |

## Public API Surface

- [x] `Level`, `LevelFilter` — verbosity levels with inverted comparisons
- [x] `Kind` — Span/Event/Hint bit flags
- [x] `Metadata` — span/event metadata struct
- [x] `Field`, `FieldSet`, `ValueSet`, `Visit` — structured key-value data
- [x] `Span::Id`, `Attributes`, `Record`, `Current` — span types
- [x] `Parent` — Root/Current/Explicit parent
- [x] `Event` — event type
- [x] `Callsite::Identifier`, `Interest`, `Interface`, `DefaultCallsite` — callsite system
- [x] `Callsites` — global callsite registry (lock-free linked list)
- [x] `Subscriber` trait — full subscriber interface
- [x] `NoSubscriber` — no-op subscriber
- [x] `Dispatch` — global default + scoped dispatch
- [x] `Dispatchers` — multi-dispatcher management with callsite interest rebuild
- [ ] Thread-local dispatch (`with_default` scoped)
- [ ] `identify_callsite!` / `metadata!` macros

## Naming Convention Map

| Rust | Crystal | Convention |
|------|---------|------------|
| `is_event()` | `event?` | predicate drops `is_` |
| `is_span()` | `span?` | same |
| `is_hint()` | `hint?` | same |
| `is_root()` | `root?` | same |
| `is_contextual()` | `contextual?` | same |
| `is_empty()` | `empty?` | same |
| `is_never()` | `never?` | same |
| `is_always()` | `always?` | same |
| `set_interest(x)` | `interest = x` | setter uses `=` |
| `set_max(x)` | `max = x` | same |
| `set_global_default(x)` | `global_default = x` | same |
| `get_default()` | `default` | getter drops `get_` |
