# porting_helpers

A Crystal shard providing utilities for behavior-faithful Crystal ports.
Used by the [`cross-language-crystal-parity`][skill] skill to manage parity
plans, inventory tracking, name mapping, and drift detection between upstream
source and Crystal implementations.

## Purpose

When porting from Rust/Go/Java/etc. to Crystal, method and type names often
diverge to follow Crystal idioms:

| Upstream (Rust) | Crystal | Convention |
|:----------------|:--------|:-----------|
| `is_event()` | `event?` | predicate drops `is_` |
| `set_interest(x)` | `interest = x` | setter uses `=` |
| `get_default()` | `default` | getter drops `get_` |

This shard tracks these mappings and validates parity between upstream and
Crystal codebases so the skill scripts can recognize `event?` as the ported
equivalent of Rust's `is_event`.

## Integration

Part of the [`cross-language-crystal-parity`][skill] ecosystem:

```
cross-language-crystal-parity (skill)
├── scripts/
│   ├── ensure_parity_plan.sh       # bootstraps inventory
│   ├── check_port_inventory.sh     # drift checks
│   ├── check_source_parity.sh
│   ├── check_test_parity.sh
│   └── verify_parity_adversarial.sh
├── lib/porting_helpers/            # ← THIS SHARD
│   ├── src/name_map.cr             # name mapping engine
│   ├── src/inventory.cr            # inventory TSV parser/writer
│   ├── src/check.cr                # drift detection
│   └── src/discover.cr            # source discovery (tree-sitter)
└── references/
    ├── usage-guidelines.md
    └── invariants.md
```

## Related

- [skill]: `~/.agents/skills/crystal_forge/skills/cross-language-crystal-parity/`
- [upstream-porting]: `~/.config/opencode/skills/porting-to-crystal/`
- Inventory format: `plans/inventory/<language>_port_inventory.tsv`
- Name mapping file: `plans/inventory/name_map.tsv`
