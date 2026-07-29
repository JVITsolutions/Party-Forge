# Godot Skill Candidates

This is a living backlog of repeatable Party Forge workflows that may be worth turning into reusable Codex skills. A candidate should be promoted only after the workflow has been used enough to identify stable inputs, steps, safety checks, and expected evidence.

## Active Candidates

### Responsive Godot UI Audit and Repair

- Detect controls that rely on resolution-specific offsets.
- Classify each control by intended attachment: corner, edge, center, or full viewport.
- Convert layout to anchors plus logical offsets without changing visual intent.
- Test center and margin invariants at multiple viewport sizes.
- Capture visual evidence at the project's target resolution.

### Scene, Resource, and Parser Validation

- Run headless Godot import and parser checks.
- Detect broken resource paths, malformed scenes, and script parse failures.
- Report exact scene or script locations and preserve generated import metadata appropriately.

### Data-Driven Content Addition

- Add a class, enemy, attack, trait, or upgrade through the project's data/resource conventions.
- Validate required fields and cross-resource references.
- Exercise the new content in focused tests and the combat sandbox.

### Godot Save-State and Git-Diff Hygiene

- Distinguish intentional editor saves from serialization-only churn.
- Preserve user changes in a dirty worktree.
- Stage and commit only the requested scope.
- Explain which Godot files must be saved and which files are generated.

### Multi-Resolution Visual Testing

- Launch controlled test runs at common logical and physical resolutions.
- Verify anchors, scaling, readability, and safe margins.
- Store screenshots with reproducible viewport metadata.

### Runtime Combat Sandbox Generation

- Create small deterministic scenarios for attacks, status effects, traits, enemies, and projectiles.
- Separate simulation checks from presentation checks.
- Produce evidence that a gameplay interaction works without requiring a full run.

## Promotion Checklist

A candidate is ready to become a skill when:

- it has been used successfully more than once;
- its inputs and outputs are clear;
- failure modes and safety boundaries are known;
- verification can produce objective evidence;
- the workflow is broader than one Party Forge file or one isolated bug.
