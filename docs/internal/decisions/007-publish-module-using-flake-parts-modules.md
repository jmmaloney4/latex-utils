# Publish latex-utils module using flake-parts.modules

*Status:* proposed

## Context

The latex-utils project currently publishes its flake-parts module by manually setting `flake.flakeModule` and `flake.flakeModules.latex-utils` in the flake outputs. Consumers import the module using `inputs.latex-utils.modules.latex-utils`. This approach works, but:

- It is not idiomatic with respect to the latest [flake-parts.modules](https://flake.parts/options/flake-parts-modules.html) conventions.
- It lacks type safety and discoverability for consumers.
- It requires manual maintenance of output attributes and documentation.
- The flake-parts ecosystem now provides a standard, type-safe, and discoverable way to publish modules under `flake.modules.<class>.<name>`, e.g., `flake.modules.flake.latex-utils`.

Migrating to this approach will make the module easier to consume, more robust, and future-proof.

### Understanding Module Classes in flake-parts

The `flake-parts` framework organizes modules into "classes" to provide structure and discoverability. This is reflected in the conventional path for accessing published modules: `flake.modules.<class>.<name>`.

- **`<class>`**: This segment categorizes the type of module. Well-known classes include:
  - `nixosModules`: For modules that configure NixOS system options (e.g., defining system services or packages), as seen in `flake-parts` documentation examples.
  - `homeModules`: For modules that configure user environments via home-manager.
- **`<name>`**: This is the specific name of the module within its designated class.

For general-purpose modules that are designed to be used within a `flake-parts` flake but do not target NixOS or home-manager specifically (like `latex-utils`, which provides options for document building and development shells), the class `flake` is used. Thus, the canonical path `flake.modules.flake.latex-utils` correctly identifies `latex-utils` as a general `flake-parts` module. This convention enhances clarity and aligns with the structured approach of the `flake-parts` ecosystem.

## Decision

We will migrate the latex-utils flake to publish its module using the idiomatic `flake-parts.modules` approach. This involves:

- Adding `inputs.flake-parts.flakeModules.modules` to the `imports` list in `flake.nix`.
- Publishing the module under `flake.modules.flake.latex-utils` as the primary, canonical path. This leverages the type-safe and discoverable module system provided by `flake-parts`.
- For backward compatibility with existing consumers, the module will also be re-exposed via `flake.flakeModule`, pointing directly to the module file (`import ./modules/latex-utils.nix;`).
- The legacy `flake.flakeModules.latex-utils` path (which was an alias to `flakeModule`) will be removed.
- Updating all internal documentation, templates, and examples to instruct consumers to primarily use the new canonical path `inputs.latex-utils.modules.flake.latex-utils` for new usage, while acknowledging `inputs.latex-utils.flakeModule` for older setups or direct import needs.
- Testing both publishing paths with consumer flakes and CI.
- Documenting the migration, including the backward compatibility measure, in release notes or relevant project documentation and notifying downstream users as needed.

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
  - Requires updating all consumer documentation and templates to reflect the new primary path.
  - Downstream users wishing to use the idiomatic path must update their import paths.
  - Minor migration effort for maintainers.

## Supersedes / Dependencies (optional)

- depends on: [flake-parts.modules documentation](https://flake.parts/options/flake-parts-modules.html)
