# PR Workflow

1. Create a feature branch from `main`
2. Implement changes and parity specs
3. Run quality gates:
   ```bash
   crystal tool format --check src spec
   ameba src spec
   crystal spec
   ```
4. Update `plans/inventory/` for the affected modules
5. Open a pull request against `main`
6. Ensure CI passes before merging
