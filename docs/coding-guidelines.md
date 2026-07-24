# Coding Guidelines

## Porting Rules

1. Upstream behavior is the source of truth. Port semantics, not Rust syntax.
2. Prefer Crystal names only when the behavior stays aligned with upstream.
3. Keep numeric widths explicit when range or signedness matters.
4. Add or update parity coverage before or alongside behavior changes.
5. Update `README.md`, `docs/*`, and `plans/parity.md` when the public surface changes.

## Naming Conventions

Crystal conventions used in this repo:

| Upstream Style | Crystal Style | Example |
|----------------|---------------|---------|
| `is_event()` | `event?` | predicate rename |
| `is_span()` | `span?` | predicate rename |
| `get_default()` | `default` | getter rename |
| `set_interest(x)` | `interest = x` | setter rename |
| `set_max(x)` | `max = x` | setter rename |

Document notable renames in `plans/inventory/` when they affect parity review.

## Type System Guidance

### Modules vs Abstract Classes

- Use `module` for trait-style behavior with no stored state.
  Example: `Tracing::Core::Subscriber` in
  [src/tracing/core/subscriber.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/core/subscriber.cr:1).
- Use `abstract class` when subclasses share hooks or stateful behavior.
  Example: `Tracing::Layer` in
  [src/tracing/subscriber/layer.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/subscriber/layer.cr:1).

### Generics

Use generics only where they preserve a meaningful type relationship.
The main example is `Layered(S)` in
[src/tracing/subscriber/layer.cr](/Volumes/extreme_ssd/repos/github.com/dsisnero/tracing.cr/src/tracing/subscriber/layer.cr:104),
which keeps the inner subscriber type intact across layer composition.

Avoid adding generic parameters just to mirror Rust types when runtime
polymorphism or aliases are clearer in Crystal.

### Enums and Flags

- Use `@[Flags]` for bitmask-style configuration enums such as `FmtSpan`.
- Use plain `enum` for mutually exclusive modes such as `Rotation`.

### Type-Erased Storage

Per-span extensions use type-erased storage. Keep those APIs stable and avoid
broad refactors without strong test coverage, because many layer features rely
on them indirectly.

## Testing Expectations

- The main suite lives in `spec/tracing_spec.cr`.
- The current suite contains `314` examples.
- New behavior should come with a focused spec whenever practical.
- For parity work, port the behavior of the upstream test rather than copying Rust structure literally.

## Comments and Divergences

- Keep comments short and behavioral.
- When Crystal diverges from upstream due to runtime or language constraints,
  document the divergence near the code and, if it affects users, in the docs.
- Use targeted `ameba:disable` comments only when there is a clear reason tied
  to parity or API surface.

## Public API Changes

If you change exported behavior under `src/tracing.cr` or add/remove methods
from `Tracing.fmt`, `FmtLayer`, `Registry`, `Layer`,
`NonBlocking`, or `FlameLayer`, update:

- `README.md`
- `docs/architecture.md`
- `docs/development.md` if the source layout changed
- `docs/testing.md` if the verification story changed
- `CHANGELOG.md`
