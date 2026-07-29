# Party Forge Godot Handbook Design

**Date:** 2026-07-29
**Status:** Approved for planning

## Purpose

Create a beginner-oriented, project-specific Godot handbook that helps the user understand how Party Forge works and make safe changes without depending entirely on Codex. The handbook will connect official Godot 4.7 concepts to the repository's actual scenes, scripts, Resources, tests, and editor workflows.

The handbook must teach both how to perform a change and how to decide which part of the project owns that change.

## Audience and Learning Model

The assumed reader is new to Godot and beginner-level in programming. The handbook will explain GDScript syntax, types, functions, signals, Resources, errors, and editor concepts as they arise.

Every practical topic uses a hybrid learning sequence:

1. Explain the Godot principle in beginner language.
2. Show where Party Forge uses it.
3. Perform the smallest safe version in a sandbox.
4. Repeat the workflow as a production integration recipe.
5. Verify the result and troubleshoot common failures.

Exercises begin in Party Forge's combat sandbox or another isolated test context. They move into production integration only after the underlying content or behavior is observable in isolation.

## Goals

- Build a correct mental model of Godot projects, nodes, scenes, instances, scripts, Resources, signals, imports, and editor state.
- Explain Party Forge's architecture and ownership boundaries.
- Teach how to inspect and modify existing content safely.
- Teach how to add an attack, recruit-only class, trait, enemy, visual asset, effect, and audio assignment.
- Distinguish a data/content change from a new behavior that requires code and tests.
- Teach saving, debugging, testing, validation, Git inspection, and recovery.
- Cite official Godot 4.7 documentation for engine behavior.
- Maintain a useful reference that can be updated as Party Forge evolves.

## Non-Goals

- Do not redesign or refactor Party Forge while writing the first handbook volume.
- Do not add the illustrative training content to the production game.
- Do not treat current Party Forge conventions as universal Godot requirements.
- Do not reproduce the Godot manual; explain only the concepts required to understand and extend this project.
- Do not provide an exhaustive GDScript programming course.
- Do not make final art, animation, audio, balance, or class-design decisions for the user.
- Do not automate workflows into Codex skills during this documentation milestone.

## Handbook Structure

Create a modular handbook under `docs/handbook/`:

1. `README.md` — start here, learning path, terminology, and exercise conventions.
2. `01-editor-and-project-files.md` — editor docks, `res://`, saving, scenes versus scripts, imported and generated files.
3. `02-nodes-scenes-and-instances.md` — Party Forge arena, actors, enemies, effects, and HUD as composed scenes.
4. `03-typed-gdscript-signals-and-data-flow.md` — beginner GDScript, static types, signals, methods, ownership, and run flow.
5. `04-resources-and-content-data.md` — custom Resources, `.tres`, exported properties, Inspector editing, validation, and `GameCatalog`.
6. `05-modifying-existing-content.md` — health, damage, cooldowns, movement, formation, traits, spawning, and upgrades.
7. `06-adding-a-class-attack-and-trait.md` — sandbox-first content creation and production registration.
8. `07-adding-an-enemy.md` — existing-behavior content versus genuinely new enemy behavior.
9. `08-visuals-audio-effects-and-ui.md` — imports, wrapper/inherited scenes, materials, collision preservation, effects, audio, and responsive UI.
10. `09-debugging-testing-saving-and-git.md` — Output, Debugger, Remote scene tree, tests, validation, save state, Git diffs, and recovery.
11. `10-party-forge-architecture-reference.md` — file map, system ownership, data flow, glossary, checklists, and official references.

The existing `docs/development/RESPONSIVE_UI_TUTORIAL.md` remains in place and is linked from the handbook rather than duplicated.

## Repeated Chapter Template

Every instructional chapter will contain, when applicable:

1. What the reader will learn.
2. The Godot mental model.
3. Where Party Forge uses the concept.
4. A list of files and editor areas involved.
5. Before-editing save and Git checks.
6. A sandbox exercise.
7. A production integration recipe.
8. An explanation of each change.
9. Expected visible and logged results.
10. Layered verification.
11. Common mistakes and diagnostic symptoms.
12. Safe rollback instructions.
13. Official Godot references.

Instructions will use explicit checkpoints:

> Stop here and run the sandbox. You should see the stated result. If you see the listed failure symptom, inspect the named Resource, scene, node, or output message before continuing.

Screenshots or diagrams are used only where editor location, scene hierarchy, or data flow is materially clearer visually. Short typed GDScript examples are annotated line by line. Longer production files are referenced by path and relevant symbol instead of being copied wholesale.

## Core Design Principles

### Identify the Owning Layer

- `.tres` Resource: content and balance data.
- `.tscn` scene: node composition, presentation, collision, and assigned dependencies.
- `.gd` script: behavior and game rules.
- Source asset plus `.import`: art or audio source and its import configuration.
- `project.godot`: project-wide display, rendering, input, physics, and application settings.

### Prefer Data Before Code

Use an existing Resource field and supported behavior when they express the intended change. Write new code only when introducing a behavior the current system does not support.

Examples:

- Changing Fighter health is a Resource edit.
- Adding another class using an existing attack kind is primarily Resource creation and registration.
- Adding a summoner class requires new behavior, scenes, integration, and tests.
- Replacing a placeholder mesh is presentation and import work, not combat logic.

### Keep Responsibilities Explicit

- Scenes are focused reusable components.
- One system owns each game rule.
- Signals announce events to interested listeners.
- Methods request an action from a known owner.
- Resources configure behavior without performing runtime scene work themselves.
- UI displays authoritative system state instead of reimplementing rules.

### Validate at Boundaries

New content must load, use a unique identifier, reference valid Resources, satisfy `validate()`, and be registered wherever the current architecture requires explicit registration.

Verification proceeds through:

1. Resource and catalog validation.
2. Focused behavior tests.
3. Combat sandbox observation.
4. Parser/import validation.
5. A complete project run when production flow changes.

## Exercise Progression

### 1. Inspect Without Changing

Trace Fighter from `data/classes/fighter.tres` through `GameCatalog`, `PartyManager`, actor configuration, combat execution, and HUD presentation.

### 2. Modify Existing Content

Adjust existing Resource values such as health, damage, cooldown, movement speed, preferred formation distance, trait tiers, and spawn timing. Explain which values are editor-exposed and which remain script constants.

### 3. Create an Attack Resource

Create a training attack using an existing `AttackDefinition.Kind`, satisfy validation, assign it in the sandbox, and observe its cooldown, range, projectile, area, or healing behavior.

### 4. Create a Recruit-Only Class

Create training attack and class Resources, register the class in `GameCatalog`, verify it appears as a recruit, and exercise it in combat. Treat selectable-leader UI as a separate optional production step because leader choices are explicitly wired today.

### 5. Add or Modify a Trait

First create or change a trait using a supported `stat_id`. Then explain that a new trait effect requires modifier or behavior code, validation support, tests, and UI communication.

### 6. Create an Enemy Using Existing Behavior

Create training enemy data and a scene based on an existing behavior. Explain the required changes to the explicit scene registry, accepted IDs, spawn schedule, sandbox, and tests.

### 7. Create a New Enemy Behavior

Explain the base `EnemyActor` contract, health, teams, targeting, movement, attacks, reward emission, transient effects, scene composition, spawn integration, and focused tests.

### 8. Replace Presentation

Import a 3D model, use a wrapper or inherited scene for game-specific nodes, assign materials, preserve collision and scripts, then add an effect or audio stream without changing combat rules.

### 9. Diagnose Deliberate Failures

Use safe training examples for missing catalog paths, duplicate IDs, broken Resource references, renamed required nodes, unsupported trait effects, and malformed imported content.

### 10. Complete Integration Check

Run content validation, focused tests, the full headless suite, parser/import initialization, combat sandbox checks, and an ordinary game run where applicable.

## Party Forge Architectural Truths to Document

The handbook must describe the current implementation rather than an idealized future version:

- `GameCatalog` contains explicit class, trait, and enemy Resource paths.
- Leader-selection UI and callbacks explicitly name the four current classes.
- Recruit generation iterates catalog classes and can discover a registered recruit-only class.
- `AttackExecutor` supports the current melee, projectile, area-projectile, and healing kinds.
- `TraitDefinition` accepts only the current supported stat IDs.
- `SpawnDirector` currently accepts and maps only Swarmer and Spitter IDs and scenes.
- Spawn scheduling currently models Swarmer and Spitter weights explicitly.
- Shared companion scenes derive presentation and combat configuration from class Resources.
- Imported presentation can change independently when scene node and script contracts are preserved.

Current limitations will be labeled as such. The handbook may describe how a future refactor could improve data-driven extensibility, but it will not implement that refactor in this milestone.

## Accuracy and Source Policy

Every technical statement is classified as one of:

- **Godot rule** — official engine behavior with an official documentation link.
- **Party Forge convention** — a repository-specific architectural choice with a file or symbol reference.
- **Current limitation** — an explicit restriction in the current implementation that may change later.

Primary official references include:

- [Nodes and scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html)
- [Signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html)
- [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html)
- [Static typing in GDScript](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html)
- [Exported GDScript properties](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html)
- [Godot best practices](https://docs.godotengine.org/en/4.7/tutorials/best_practices/index.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
- [Learning new features and using the class reference](https://docs.godotengine.org/en/4.7/getting_started/introduction/learning_new_features.html)
- [Introduction to 3D](https://docs.godotengine.org/en/4.7/tutorials/3d/introduction_to_3d.html)
- [Importing 3D scenes](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html)
- [Multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html)
- [Debug tools](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/index.html)
- [Output panel](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/output_panel.html)

Where a `4.7` page is unavailable or redirects to stable documentation, the handbook will state the version context and avoid relying on behavior that differs from Party Forge's installed Godot 4.7.1.

## Safety and Troubleshooting

Before every production exercise, the reader will:

1. Save relevant Godot scenes, scripts, and Resources.
2. Close or stop the currently running test instance when necessary.
3. Record `git status --short`.
4. Identify the exact files expected to change.
5. Test the sandbox step before production registration.

Troubleshooting entries use:

> Symptom → likely ownership layer → what to inspect → safe correction → verification

The handbook will warn about:

- shared Resource instances and unintended global changes;
- editing generated `.godot/imported/` files;
- discarding `.import` metadata;
- editing an imported scene directly and losing changes on reimport;
- renaming nodes that scripts access by path;
- running the wrong scene with `F5` versus `F6`;
- saving only one of several changed resources;
- editor serialization changes appearing beside intentional changes;
- unsupported IDs, attack kinds, trait effects, or enemy registrations.

Every destructive recovery instruction must identify its exact target and offer a recoverable or Git-based option first.

## Documentation Validation

Before the handbook is considered complete:

- every referenced Party Forge path exists;
- named node paths and symbols match the current repository;
- example Resources satisfy current validation rules;
- commands are copied exactly and exercised where safe;
- official links resolve to the intended Godot documentation;
- screenshots show the current editor and state the Godot version;
- the handbook contains no placeholders or unexplained future steps;
- the full project test suite and parser/import check remain unchanged and passing because this milestone adds documentation only.

## Maintenance

`docs/handbook/README.md` will include a version header containing:

- Party Forge commit used for verification;
- Godot version (`4.7.1` at initial publication);
- date last checked;
- list of chapters and their intended reading order.

When architecture changes, update the affected production recipe, the architecture reference, and the verification commit together. Avoid duplicating full instructions across chapters; link to the owning chapter instead.

## Success Criteria

The first handbook volume is successful when a beginner can:

- explain the difference between a Node, scene, script, and Resource;
- locate the authoritative data for a class, attack, trait, enemy, or UI layout;
- modify an existing content value and verify its effect;
- create a valid training attack and class in the sandbox;
- describe every registration step required for production integration;
- distinguish existing-behavior content from a new behavior requiring code;
- import and wrap a visual asset without overwriting gameplay nodes;
- use the Output panel, Debugger, Remote scene tree, tests, and Git status to investigate a failure;
- undo an exercise safely;
- find the relevant official Godot documentation for the concept being used.
