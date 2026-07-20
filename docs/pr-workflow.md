# PR Workflow

## Commits

Use concise, behavior-oriented commit subjects.

Recommended prefixes:

- `port:` for upstream parity work
- `fix:` for behavior corrections
- `docs:` for documentation-only changes
- `refactor:` for internal structure changes with no behavior change

Examples:

```text
port: add reloadable fmt filter support
port: bridge tracing spans to OpenTelemetry export
fix: flush remaining spans on FlameGuard close
docs: update README and architecture for subscriber layout
```

## Before Opening a PR

1. Run the quality gates:

   ```bash
   crystal tool format --check src spec
   ameba src spec
   crystal spec
   ```

2. If parity status changed, update:

   - `plans/parity.md`
   - the relevant file under `plans/inventory/`

3. If the public surface changed, update:

   - `README.md`
   - `CHANGELOG.md`
   - `docs/*` as needed

4. Verify inventory drift when relevant:

   ```bash
   ./scripts/check_port_inventory.sh . plans/inventory/rust_port_inventory.tsv vendor/tracing rust
   ```

5. Review the diff for accidental path churn or stale docs.

## Review Checklist

- [ ] `crystal tool format --check src spec` passes
- [ ] `ameba src spec` passes
- [ ] `crystal spec` passes
- [ ] New behavior is covered by focused tests
- [ ] `README.md` and `docs/*` match the current public API
- [ ] `plans/parity.md` and inventory files were updated if parity changed
- [ ] Any intentional divergence from upstream is documented

## Branch Naming

Recommended branch names:

```text
port/<feature-name>
fix/<bug-description>
refactor/<subsystem>
docs/<topic>
```

## Documentation Rule

Do not leave docs updates for later when the public API moved in the same patch.
This repo changes layout and exported surface often enough that stale examples
quickly become misleading.
