# ADR 006: Publish latex-utils module using flake-parts.modules
*Date:* 2024-06-09
*Status:* proposed

## Context

The latex-utils project currently publishes its flake-parts module by manually setting `flake.flakeModule` and `flake.flakeModules.latex-utils` in the flake outputs. Consumers import the module using `inputs.latex-utils.modules.latex-utils`. This approach works, but:

- It is not idiomatic with respect to the latest [flake-parts.modules](https://flake.parts/options/flake-parts-modules.html) conventions.
- It lacks type safety and discoverability for consumers.
- It requires manual maintenance of output attributes and documentation.
- The flake-parts ecosystem now provides a standard, type-safe, and discoverable way to publish modules under `flake.modules.<class>.<name>`, e.g., `flake.modules.flake.latex-utils`.

Migrating to this approach will make the module easier to consume, more robust, and future-proof.

## Decision

We will migrate the latex-utils flake to publish its module using the idiomatic `flake-parts.modules` approach. This involves:

- Adding `inputs.flake-parts.flakeModules.modules` to the `imports` list in `flake.nix`.
- Publishing the module under `flake.modules.flake.latex-utils` instead of `flake.flakeModule` or `flake.flakeModules.latex-utils`.
- Updating all documentation, templates, and examples to instruct consumers to use `inputs.latex-utils.modules.flake.latex-utils`.
- Removing legacy exports (`flakeModule`, `flakeModules`) from the outputs.
- Testing the new publishing path with consumer flakes and CI.
- Documenting the migration in the agent changelog and notifying downstream users as needed.

## Alternatives Considered
1. **Continue manual publishing (status quo)** – Rejected: Not idiomatic, more error-prone, lacks type safety and discoverability.
2. **Adopt a custom module publishing convention** – Rejected: Reinvents the wheel, increases maintenance burden, and diverges from community standards.
3. **Adopt flake-parts.modules (chosen)** – Provides a standard, type-safe, and discoverable publishing path, aligns with upstream documentation and best practices.

## Consequences
- **Pros:**
  - Module is published in a standard, discoverable location for all flake-parts users.
  - Type safety: prevents accidental misuse of module classes.
  - Reduces boilerplate and manual maintenance in flake outputs.
  - Aligns with community best practices and future flake-parts tooling.
  - Easier for downstream consumers to use and understand.
- **Cons:**
  - Requires updating all consumer documentation and templates.
  - Downstream users must update their import paths.
  - Minor migration effort for maintainers.

## Supersedes / Dependencies (optional)
- depends on: [flake-parts.modules documentation](https://flake.parts/options/flake-parts-modules.html) 