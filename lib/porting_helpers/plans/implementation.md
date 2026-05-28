# Implementation Plan — porting_helpers

## Goals

A Crystal CLI/library shard that provides the data layer for the
`cross-language-crystal-parity` skill scripts. Currently the skill scripts
are in Ruby (`parity_inventory_lib.rb`, `check_*_parity.rb`). This shard
replaces the data-parsing and check logic with Crystal-native code, giving:

1. **Name mapping** — translate Rust/Go method names to Crystal idioms so
   `check_port_inventory` doesn't flag `event?` as "stale" when Rust has
   `is_event`.
2. **Inventory TSV parsing** — read/write the inventory ledger format.
3. **Drift detection** — set-difference logic for missing/stale items.
4. **Source discovery** — tree-sitter or regex extraction of declarations
   from upstream + Crystal source (replaces Ruby regex fallback).
5. **Name map file** — load `plans/inventory/name_map.tsv` with explicit
   renames for cases heuristics can't handle.

## Context: The Parity Skill

Location: `~/.agents/skills/crystal_forge/skills/cross-language-crystal-parity/`

The skill manages these artifacts:

| File | Purpose | Format |
|:-----|:--------|:-------|
| `plans/parity.md` | Curated feature plan | Markdown checkboxes |
| `plans/inventory/<lang>_port_inventory.tsv` | Working ledger | 5-column TSV |
| `plans/inventory/<lang>_source_parity.tsv` | Upstream API manifest | 4-column TSV |
| `plans/inventory/<lang>_test_parity.tsv` | Upstream test manifest | 4-column TSV |
| `plans/inventory/<lang>_source_notes.tsv` | Deterministic override notes | 2-column TSV |
| `plans/inventory/name_map.tsv` | Explicit name renames | 2-column TSV (new) |

### TSV Format: Port Inventory (5 columns)

```
# source_id	kind	status	crystal_refs	notes
vendor/tracing/tracing-core/src/metadata.rs::func::is_event	func	ported	Metadata#event?	port parity
vendor/tracing/tracing-core/src/span.rs::method::Attributes.is_root	method	ported	Attributes#root?	port parity
```

**Status values**: `missing`, `in_progress`, `partial`, `ported`, `skipped`, `intentional_divergence`

**Invariant**: `ported` and `partial` rows MUST have non-empty `crystal_refs`.

### TSV Format: Source/Test Manifest (4 columns)

```
# header_id	status	crystal_refs	notes
vendor/tracing/tracing-core/src/metadata.rs::func::is_event	missing	-	baseline
```

Auto-generated from upstream source discovery. Regenerated only with force flag.

### TSV Format: Name Map (2 columns) — NEW

```
# upstream_name	crystal_name
is_event	event?
set_interest	interest=
get_default	default
is_contextual	contextual?
```

Used by check scripts to translate discovered Rust/Go names before comparing
against the Crystal inventory.

## Core Problem: Name Matching

`check_port_inventory.rb` does set-difference matching:

```ruby
missing = discovered_ids - manifest_ids   # Rust items not tracked
stale   = manifest_ids - discovered_ids   # Crystal items not in Rust
```

When Crystal uses `event?` and Rust uses `is_event`, these IDs never match,
causing false "missing" and "stale" reports.

**Solution**: Before computing set differences, translate all upstream IDs
through the name map + heuristic rules so they align with Crystal names.

### Heuristic Rules (applied before explicit name_map.tsv lookup)

| Rust Pattern | Crystal Pattern | Example |
|:-------------|:----------------|:--------|
| `is_foo` | `foo?` | `is_empty` → `empty?` |
| `set_foo` | `foo=` | `set_interest` → `interest=` |
| `get_foo` | `foo` | `get_default` → `default` |
| `has_foo` | `foo?` | `has_explicit_parent` → `explicit_parent?` |

### Name Map File (explicit overrides)

For cases heuristics can't handle or where the mapper should be explicit:
```
plans/inventory/name_map.tsv
```

The check scripts load this file and apply mappings before comparison.
If a Rust name appears in name_map, the mapped Crystal name overrides any
heuristic result.

## Source Discovery

The skill scripts support three parser modes (`auto`, `regex`, `tree-sitter`).

### Regex Extraction (Ruby)

`parity_inventory_lib.rb` already has regex extractors for all 6 languages
(go, rust, crystal, java, ruby, typescript). These parse declarations:

```ruby
# Rust
/^pub\s+fn\s+([a-z_][A-Za-z0-9_]*)\s*\(/  → func
/^pub\s+struct\s+([A-Z][A-Za-z0-9_]*)\b/  → struct
/^pub\s+trait\s+([A-Z][A-Za-z0-9_]*)\b/   → trait

# Crystal
/^(class|module|struct|enum)\s+([A-Z][A-Za-z0-9_:]*)/ → kind + name
/^def\s+(self\.)?([a-z_][A-Za-z0-9_!?=]*)/           → func/method
```

### Tree-Sitter Discovery (Crystal binary)

The skill looks for `chiasmus-discover` binary at `skill/bin/` or
`skill/src/chiasmus_discover.cr`. Uses tree-sitter query patterns for
higher accuracy. Falls back to regex if unavailable.

## Implementation Phases

### Phase 1: Name Mapping Engine (priority: high)

Files: `src/name_map.cr`, `spec/name_map_spec.cr`

- Load `name_map.tsv`
- Apply heuristic rules (is_→?, set_→=, get_→, has_→?)
- Apply explicit overrides from TSV
- Translate a single name: `NameMap.translate("is_event") → "event?"`
- Translate a source_id: `NameMap.translate_id("metadata.rs::func::is_event") → "metadata.rs::func::event?"`
- Handle Rust type-qualified methods: `Metadata.is_event` → `Metadata.event?`
- CLI: `porting_helpers translate is_event` → `event?`

API sketch:
```crystal
module PortingHelpers
  class NameMap
    def initialize(name_map_path : String)
    end

    def translate(name : String) : String
    end

    def translate_id(source_id : String) : String
    end

    # Load heuristic rules + explicit overrides
    private def load_heuristic_rules
    end
  end
end
```

### Phase 2: Inventory TSV Parser (priority: high)

Files: `src/inventory.cr`, `spec/inventory_spec.cr`

- Read inventory TSV files (port_inventory, source_parity, test_parity)
- Validate status values
- Validate refs for ported/partial rows
- Write inventory TSV (auto-generate from discovery)
- CLI: `porting_helpers inventory check plans/inventory/rust_port_inventory.tsv`
- CLI: `porting_helpers inventory generate vendor/tracing rust`

API sketch:
```crystal
module PortingHelpers
  class Inventory
    struct Row
      property source_id : String
      property kind : String
      property status : String
      property crystal_refs : String
      property notes : String
    end

    def self.load(path : String) : Array(Row)
    end

    def self.validate(rows : Array(Row)) : Array(String)  # returns errors
    end

    def self.write(path : String, rows : Array(Row))
    end
  end
end
```

### Phase 3: Drift Detection / Check (priority: high)

Files: `src/check.cr`, `spec/check_spec.cr`

- Compare discovered upstream IDs against inventory (with name mapping)
- Report: missing (upstream items not tracked), stale (inventory items not in upstream)
- Status validation (valid statuses, refs required for ported/partial)
- Duplicate detection
- CLI: `porting_helpers check inventory plans/inventory/rust_port_inventory.tsv vendor/tracing rust --name-map plans/inventory/name_map.tsv`

API sketch:
```crystal
module PortingHelpers
  class Check
    def self.run_inventory(
      manifest_path : String,
      source_path : String,
      language : String,
      name_map : NameMap? = nil
    ) : CheckResult
    end

    struct CheckResult
      property missing : Array(String)
      property stale : Array(String)
      property errors : Array(String)
      property ok : Bool
    end
  end
end
```

### Phase 4: Source Discovery (priority: medium)

Files: `src/discover.cr`, `spec/discover_spec.cr`

- Regex-based extraction for Rust and Crystal (port Ruby regex patterns)
- Integration with tree-sitter if available
- Emit `Item` structs with id, kind, scope, file, name
- CLI: `porting_helpers discover vendor/tracing rust`

API sketch:
```crystal
module PortingHelpers
  struct Item
    property id : String      # "metadata.rs::func::is_event"
    property kind : String    # "func", "struct", "enum", "trait", etc.
    property scope : String   # "source" | "test"
    property file : String    # relative path
    property name : String    # "is_event"
  end

  class Discoverer
    def initialize(source_path : String, language : String, parser : String = "auto")
    end

    def discover : Array(Item)
    end

    private def discover_regex : Array(Item)
    end

    private def discover_treesitter : Array(Item)
    end

    private def extract_rust(content : String, rel : String) : Tuple(Array(Item), Array(Item))
    end

    private def extract_crystal(content : String, rel : String) : Tuple(Array(Item), Array(Item))
    end
  end
end
```

### Phase 5: CLI Integration (priority: low)

Files: `src/cli.cr`, `src/porting_helpers.cr`

- Unified CLI with subcommands: `translate`, `inventory`, `check`, `discover`
- Accept same flags as the Ruby scripts (`--root`, `--source`, `--language`, `--parser`, `--name-map`)
- Return exit codes matching Ruby scripts (0=ok, 1=drift, 2=errors)

## Integration with Skill Scripts

The Ruby scripts in the skill (`check_port_inventory.sh` → `check_port_inventory.rb`)
can be updated to call the Crystal binary instead. Two approaches:

### A. Side-by-side (recommended for transition)

Keep Ruby scripts as the primary interface. The Crystal shard provides the data
layer they call into:

```bash
# check_port_inventory.sh (updated)
crystal run lib/porting_helpers/src/cli.cr -- check inventory \
  --manifest "$MANIFEST" --source "$SOURCE_PATH" --language "$LANGUAGE" \
  --name-map "plans/inventory/name_map.tsv"
```

### B. Native replacement

Replace Ruby scripts entirely with Crystal binaries compiled from this shard.
Reduces dependency on Ruby but requires more effort.

## Spec Strategy

Each phase includes specs:

| Phase | Spec | What it tests |
|:------|:-----|:--------------|
| 1 | `spec/name_map_spec.cr` | Heuristic rules, explicit overrides, source_id translation |
| 2 | `spec/inventory_spec.cr` | Read/write TSV, status validation, ref enforcement |
| 3 | `spec/check_spec.cr` | Set-difference logic, name-mapped comparison, error reporting |
| 4 | `spec/discover_spec.cr` | Regex extraction for Rust and Crystal source files |

Use fixture files in `spec/fixtures/`:
- `spec/fixtures/name_map.tsv`
- `spec/fixtures/rust_port_inventory.tsv`
- `spec/fixtures/sample_metadata.rs`

## Files to Create

```
lib/porting_helpers/
├── README.md                          # this file
├── plans/implementation.md            # this plan
├── shard.yml                          # crystal init already done
├── .ameba.yml
├── src/
│   ├── porting_helpers.cr             # require all, CLI entry
│   ├── name_map.cr                    # Phase 1
│   ├── inventory.cr                   # Phase 2
│   ├── check.cr                       # Phase 3
│   └── discover.cr                    # Phase 4
└── spec/
    ├── spec_helper.cr
    ├── name_map_spec.cr               # Phase 1
    ├── inventory_spec.cr              # Phase 2
    ├── check_spec.cr                  # Phase 3
    ├── discover_spec.cr               # Phase 4
    └── fixtures/
        ├── name_map.tsv
        ├── rust_port_inventory.tsv
        └── sample_metadata.rs
```

## References

- Skill scripts: `~/.agents/skills/crystal_forge/skills/cross-language-crystal-parity/scripts/`
- Key Ruby file: `parity_inventory_lib.rb` (623 lines, all 6 language regex extractors)
- Invariant docs: `references/invariants.md`, `references/usage-guidelines.md`
- Real inventory example: `../../plans/inventory/tracing-core.md` (upstream project)

## Start Here

Begin with **Phase 1** (NameMap). It's self-contained, has clear specs, and
unblocks the check scripts. The heuristic rules are:

```
is_foo  → foo?
has_foo → foo?
set_foo → foo=
get_foo → foo
```

Load explicit overrides from `name_map.tsv` to supersede heuristics.
