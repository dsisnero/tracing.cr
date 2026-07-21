# tracing-chrome Parity Plan

Upstream: **tracing-chrome** pinned at `v0.7.2` (submodule `vendor/tracing-chrome/`,
commit `1753f9e`).

`tracing-chrome` is tracked separately from `vendor/tracing/` because it is a
standalone ecosystem crate, not part of the `tokio-rs/tracing` workspace. Its
inventory and parity manifests should therefore live in dedicated files rather
than being folded into the main `rust_*` ledgers.

## Inventory Files

- `plans/inventory/tracing_chrome_port_inventory.tsv`
- `plans/inventory/tracing_chrome_source_parity.tsv`
- `plans/inventory/tracing_chrome_test_parity.tsv`

As of July 20, 2026, `vendor/tracing-chrome` has no discoverable Rust test
items for the parity tooling. The checked-in test manifest is therefore an
empty header-only ledger until upstream adds tests or the parser discovers
them.

## Make Targets

Generate the curated port ledger:

```bash
make gen-inventory-tracing-chrome
```

Generate the reference manifests:

```bash
make gen-source-parity-tracing-chrome
make gen-test-parity-tracing-chrome
```

Run drift checks:

```bash
make check-inventory-tracing-chrome
make check-source-parity-tracing-chrome
make check-test-parity-tracing-chrome
```

## Workflow

1. Generate the three tracing-chrome inventory/parity files.
2. Curate `tracing_chrome_port_inventory.tsv` as the working ledger.
3. Keep the source/test parity TSVs generated and refresh them only when the
   upstream submodule is intentionally updated.
4. Update [parity.md](./parity.md) when tracing-chrome becomes part of the
   shipped surface or when its scope/status changes materially.
