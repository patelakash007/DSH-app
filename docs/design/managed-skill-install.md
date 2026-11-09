# Managed Skill Installation & Lifecycle

Protocol for installing, validating, and updating managed agent skills.

## Architecture
- Skills declared via standard `SKILL.md` frontmatter with clear invocation criteria (`whenToUse`).
- Atomic filesystem installation in `$DSH_HOME/skills/` preserving user customizations.
- Version tracking and automatic schema upgrade checks.
