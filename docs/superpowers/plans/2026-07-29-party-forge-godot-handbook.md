# Party Forge Godot Handbook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a beginner-oriented, Party Forge-specific Godot handbook that teaches engine fundamentals, safe content creation, presentation workflows, and evidence-based debugging through sandbox-first exercises.

**Architecture:** Eleven modular Markdown documents under `docs/handbook/` form one ordered learning path and remain independently searchable. Each chapter distinguishes official Godot behavior from Party Forge conventions and current limitations, then connects principles to exact repository files, sandbox exercises, production recipes, verification, troubleshooting, and rollback.

**Tech Stack:** Godot 4.7.1 stable Mono editor, typed GDScript, Godot scenes and custom Resources, Markdown, PowerShell validation, Git, and official Godot 4.7 documentation.

## Global Constraints

- Assume the reader is new to Godot and beginner-level in programming.
- Use the approved sequence: principle → Party Forge example → sandbox exercise → production recipe → verification → troubleshooting → rollback → official references.
- Teach sandbox-first workflows; do not add illustrative training content to the production game while authoring the handbook.
- This milestone creates documentation only. Do not modify `project.godot`, production scripts, scenes, Resources, tests, addons, or imported assets.
- Label guidance as **Godot rule**, **Party Forge convention**, or **Current limitation** whenever the distinction matters.
- Cite official Godot 4.7 documentation for engine behavior. If a page redirects to stable documentation, state the version context.
- Describe current Party Forge architecture accurately, including explicit catalog paths, class-selection wiring, supported attack/trait kinds, and SpawnDirector limitations.
- Use clearly labeled neutral training examples; do not make new Party Forge class, enemy, visual, audio, or balance decisions.
- Prefer Inspector/editor instructions; use raw `.tscn` and `.tres` text only to teach structure or diagnose failures.
- Preserve the user's current dirty scripts and all untracked work, including `addons/`, `data/classes/marksman.tres`, and generated UID files.
- Stage and commit only the handbook files named by each task.
- Do not duplicate the existing responsive UI tutorial; link to `docs/development/RESPONSIVE_UI_TUTORIAL.md`.
- Use lowercase `snake_case` for paths and PascalCase for node names when explaining naming conventions.
- Every chapter must contain exact Party Forge paths, observable checkpoints, safe rollback guidance, and official references.
- The handbook version header must state: verified architecture commit `a293f62`, Godot `4.7.1`, and initial check date `2026-07-29`.

## File Structure

- Create `docs/handbook/README.md`: entry point, version header, reading order, labeling conventions, and quick links.
- Create `docs/handbook/01-editor-and-project-files.md`: editor, `res://`, file types, saving, imports, and run controls.
- Create `docs/handbook/02-nodes-scenes-and-instances.md`: node/scene mental model and Party Forge scene composition.
- Create `docs/handbook/03-typed-gdscript-signals-and-data-flow.md`: beginner typed GDScript and authoritative event flow.
- Create `docs/handbook/04-resources-and-content-data.md`: custom Resources, Inspector editing, catalog loading, and validation.
- Create `docs/handbook/05-modifying-existing-content.md`: safe balance and content modifications.
- Create `docs/handbook/06-adding-a-class-attack-and-trait.md`: exact training content exercise and production registration map.
- Create `docs/handbook/07-adding-an-enemy.md`: existing-behavior enemy exercise and new-behavior boundary.
- Create `docs/handbook/08-visuals-audio-effects-and-ui.md`: asset importing, wrapper scenes, materials, collision, audio, effects, and UI.
- Create `docs/handbook/09-debugging-testing-saving-and-git.md`: diagnostic tools, validation, save state, Git review, and recovery.
- Create `docs/handbook/10-party-forge-architecture-reference.md`: system ownership, file map, data flow, registries, glossary, and checklists.

## Shared Chapter Contract

Every numbered chapter must begin with this metadata block, using its own title and summary:

```markdown
> **Handbook version:** Party Forge architecture verified at `a293f62`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-29`

## What you will learn

- Distinguish the Godot concepts introduced by the chapter.
- Locate their concrete Party Forge examples.
- Complete and verify the chapter's sandbox exercise safely.
```

Replace the three illustrative bullets with three to five chapter-specific, observable abilities. Do not copy generic learning objectives into the final chapters.

Use these callout labels consistently:

```markdown
> **Godot rule:** Engine behavior supported by an official Godot reference.

> **Party Forge convention:** A choice made by this repository.

> **Current limitation:** An explicit restriction in the current implementation.

> **Checkpoint:** An observable result the reader must verify before continuing.
```

---

### Task 1: Handbook Entry Point and Scene Foundations

**Files:**

- Create: `docs/handbook/README.md`
- Create: `docs/handbook/01-editor-and-project-files.md`
- Create: `docs/handbook/02-nodes-scenes-and-instances.md`

**Interfaces:**

- Consumes: repository state at `a293f62`, `project.godot`, `scenes/game/main.tscn`, and the shared chapter contract.
- Produces: the handbook navigation contract, shared vocabulary, and node/scene mental model used by Tasks 2–5.

- [ ] **Step 1: Record the documentation boundary and confirm the three files do not already exist**

Run:

```powershell
git status --short
$taskFiles = @(
	'docs/handbook/README.md',
	'docs/handbook/01-editor-and-project-files.md',
    'docs/handbook/02-nodes-scenes-and-instances.md'
)
$taskFiles | ForEach-Object { "$_ exists=$(Test-Path $_)" }
```

Expected: the status includes the user's existing dirty/untracked files; each task file reports `exists=False`. Stop if a task file already exists and inspect it instead of overwriting it.

- [ ] **Step 2: Create the handbook entry point with exact navigation and conventions**

Create `docs/handbook/README.md` with these sections and facts:

```markdown
# Party Forge Godot Handbook

> **Verified architecture commit:** `a293f62`<br>
> **Godot version:** `4.7.1`<br>
> **Initial check date:** `2026-07-29`

## Who this is for
## How to use the handbook
## Before every exercise
## Learning path
## Reference path
## Callout labels
## What this handbook will not do
## Official Godot starting points
```

Requirements for the content:

- State that no prior Godot knowledge is assumed, but the reader should follow chapters in order the first time.
- Explain the hybrid chapter sequence and sandbox-before-production rule.
- In `Before every exercise`, require `Ctrl+S`, stopping the running game when needed, `git status --short`, and identifying expected changed files.
- Link all ten numbered chapters using relative Markdown links.
- Link `../development/RESPONSIVE_UI_TUTORIAL.md` as the focused responsive-layout reference.
- Define the four callout labels from the shared contract.
- State that example training content is disposable and must not be mistaken for an approved Party Forge design.
- Link the official Godot 4.7 [Step by step](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/index.html), [Learning new features](https://docs.godotengine.org/en/4.7/getting_started/introduction/learning_new_features.html), and [Tutorials](https://docs.godotengine.org/en/4.7/tutorials/index.html) pages.

- [ ] **Step 3: Write the editor and project-files chapter**

Create `docs/handbook/01-editor-and-project-files.md` with these headings:

```markdown
# 1. The Godot Editor and Party Forge Project Files
## What you will learn
## The editor areas you will use
## What `res://` means
## Party Forge file types
## What saving actually saves
## F5, F6, and F8
## Imported versus generated files
## Exercise: inspect the project without changing it
## Production habit: predict the changed files
## Verification
## Common mistakes
## How to undo an accidental editor change
## Official Godot references
```

Required facts and examples:

- Name the Scene, FileSystem, Inspector, Output, Debugger, 2D, 3D, Script, and Game areas and explain their purpose in plain language.
- Define `res://` as the project root and map it to the Party Forge directory without presenting an absolute Windows path as portable project data.
- Explain `.tscn`, `.tres`, `.gd`, `.uid`, source assets, `.import`, `.godot/`, and `project.godot`.
- State that scenes, scripts, and external Resources are individual files; there is no single monolithic “save project” file.
- Explain `F5` runs `scenes/game/main.tscn`, `F6` runs the current scene, and `F8` stops the run.
- Explain that `.import` metadata is versioned but `.godot/imported/` is regenerable cache data.
- Exercise: locate `project.godot`, `scenes/game/main.tscn`, `data/classes/fighter.tres`, and `scripts/game/main.gd`; inspect each without editing; run `F5`; stop with `F8`; compare `git status --short` before and after.
- Rollback: use Godot's Undo for unsaved editor changes; close without saving only when the exact unsaved scope is understood; never recommend `git reset --hard`.
- Cite [Nodes and scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html), [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html), and [Import process](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html).

- [ ] **Step 4: Write the nodes, scenes, and instances chapter**

Create `docs/handbook/02-nodes-scenes-and-instances.md` with these headings:

```markdown
# 2. Nodes, Scenes, and Instances
## What you will learn
## Node, scene, and instance mental model
## Local and global ownership
## Party Forge's main scene
## Reusable actor, enemy, effect, and UI scenes
## Parent and child paths
## Exercise: trace an instantiated companion
## Production recipe: add presentation without moving behavior
## Verification with the Local and Remote scene trees
## Common mistakes
## Rollback
## Official Godot references
```

Required facts and examples:

- Explain a Node as one focused engine object, a scene as a saved tree with one root, and an instance as a reusable copy of that scene.
- Describe `scenes/game/main.tscn` as the composition root containing `GameRun`, `PartyManager`, `ExperienceSystem`, `SpawnDirector`, `PartyActorSpawner`, `Arena`, actor/enemy/effect containers, and `HUD`.
- Explain that `scenes/characters/companion.tscn`, enemy scenes, projectile/effect scenes, and UI panels are reusable components.
- Explain local versus global transforms using Party Forge's `Node3D` actors and effects.
- Explain that paths such as `HUD/LevelUpPanel` depend on node names and hierarchy; renaming a required node can break code.
- Trace `PartyManager.member_added` → `PartyActorSpawner._on_member_added()` → instantiation of `companion.tscn` → `configure()` and `configure_combat()` → health-bar child.
- Exercise: run the game, select a leader, recruit or use the sandbox, switch the Scene dock to Remote, and locate the runtime companion and its `HealthComponent`, `AttackController`, and health-bar child.
- Production recipe: add a purely visual child under an actor wrapper scene while preserving the scripted root, collision, `HealthComponent`, `AttackController`, and expected node names.
- Cite [Nodes and scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html), [Creating instances](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/instancing.html), and [Godot classes, scripts, and scenes](https://docs.godotengine.org/en/4.7/tutorials/best_practices/what_are_godot_classes.html).

- [ ] **Step 5: Validate Task 1 navigation, required sections, and repository references**

Run:

```powershell
$taskFiles = @(
	'docs/handbook/README.md',
	'docs/handbook/01-editor-and-project-files.md',
    'docs/handbook/02-nodes-scenes-and-instances.md'
)
$taskFiles | ForEach-Object {
	if (-not (Test-Path $_)) { throw "Missing handbook file: $_" }
}
$requiredRepoPaths = @(
	'project.godot',
	'scenes/game/main.tscn',
	'scenes/characters/companion.tscn',
	'data/classes/fighter.tres',
	'scripts/game/main.gd',
	'scripts/party/party_actor_spawner.gd',
    'docs/development/RESPONSIVE_UI_TUTORIAL.md'
)
$requiredRepoPaths | ForEach-Object {
	if (-not (Test-Path $_)) { throw "Broken Party Forge path: $_" }
}
$taskFiles | ForEach-Object {
	if (-not (Select-String -Path $_ -Pattern 'Godot version' -Quiet)) { throw "Missing version metadata: $_" }
	if (Select-String -Path $_ -Pattern 'TBD|TODO|fill in|implement later' -Quiet) { throw "Placeholder text: $_" }
}
git diff --check -- $taskFiles
```

Expected: no exceptions and no `git diff --check` output.

- [ ] **Step 6: Commit the foundations without staging unrelated work**

Run:

```powershell
git add -- docs/handbook/README.md docs/handbook/01-editor-and-project-files.md docs/handbook/02-nodes-scenes-and-instances.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: teach Party Forge Godot foundations"
```

Expected: the staged list contains exactly the three Task 1 files; the user's dirty and untracked files remain unstaged.

---

### Task 2: Typed GDScript, Signals, Resources, and Content Data

**Files:**

- Create: `docs/handbook/03-typed-gdscript-signals-and-data-flow.md`
- Create: `docs/handbook/04-resources-and-content-data.md`

**Interfaces:**

- Consumes: the vocabulary and ownership model from Task 1; `ClassDefinition`, `AttackDefinition`, `TraitDefinition`, `EnemyDefinition`, `GameCatalog`, and the main run flow.
- Produces: the typed-code and Resource concepts required by the content recipes in Tasks 3 and 4.

- [ ] **Step 1: Write the typed GDScript, signals, and data-flow chapter**

Create `docs/handbook/03-typed-gdscript-signals-and-data-flow.md` with these headings:

```markdown
# 3. Typed GDScript, Signals, and Party Forge Data Flow
## What you will learn
## Reading a typed GDScript file
## `extends`, `class_name`, variables, constants, and functions
## Types, arrays, dictionaries, enums, and StringName
## `_ready`, `_process`, and `_physics_process`
## Methods request actions; signals announce events
## Party Forge run flow
## Exercise: follow one event through the game
## Production recipe: connect a new presentation response
## Verification
## Common errors and debugger messages
## Rollback
## Official Godot references
```

Required facts and examples:

- Annotate short excerpts showing `class_name ClassDefinition`, `extends Resource`, `@export var max_health: float`, typed parameters/returns, `Array[StringName]`, and an enum.
- Explain `StringName` as the identifier type used for class, trait, attack, enemy, group, and signal-related IDs; do not claim it automatically validates spelling.
- Explain `_ready()` for post-instantiation setup, `_process()` for frame updates, and `_physics_process()` for physics-timed movement.
- Use exact signal examples: `PartyManager.member_added`, `EnemyActor.reward_dropped`, `ExperienceSystem.level_ready`, and `GameRun.victory`/`defeat`.
- Trace: class selection → catalog lookup → party initialization → leader instance → auto-combat → enemy reward → experience → level-ready signal → UI choice → party update.
- Exercise: choose one emitted signal, set a breakpoint in its receiver, run the sandbox or project, and inspect typed arguments and owning nodes.
- Production recipe: connect an existing authoritative signal to a new visual-only response without duplicating the game rule.
- Explain common parser messages: unknown identifier, invalid type assignment, nonexistent function/property, and bad indentation.
- Cite [Static typing](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/static_typing.html), [GDScript basics](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_basics.html), [Signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html), and [Idle and physics processing](https://docs.godotengine.org/en/4.7/tutorials/scripting/idle_and_physics_processing.html).

- [ ] **Step 2: Write the Resources and content-data chapter**

Create `docs/handbook/04-resources-and-content-data.md` with these headings:

```markdown
# 4. Resources and Party Forge Content Data
## What you will learn
## Nodes perform work; Resources describe data
## External and built-in Resources
## Exported properties and the Inspector
## Party Forge definition types
## Loading, caching, and shared Resource instances
## GameCatalog and explicit registration
## Validation and grep-friendly errors
## Exercise: inspect and duplicate an attack Resource
## Production recipe: decide whether a change is data or behavior
## Verification
## Common mistakes
## Rollback
## Official Godot references
```

Required facts and examples:

- Explain external `.tres` versus scene-built-in Resources and warn that loaded Resources are cached/shared.
- Explain `@export` and how `class_name` makes custom Resource types available in the editor.
- Map exact definition types and paths: `AttackDefinition`, `ClassDefinition`, `TraitDefinition`, `EnemyDefinition`, and `UpgradeTuning` under `scripts/data/` and `data/`.
- Explain `load()` versus `preload()` using Party Forge examples without implying one is universally superior.
- Document `GameCatalog.CLASS_PATHS`, `TRAIT_PATHS`, and `ENEMY_PATHS` as current explicit registries.
- Explain `validate()` results, duplicate-ID detection, and `PARTY_FORGE_RESOURCE_ERROR` formatting.
- Exercise: duplicate `data/attacks/ranger_shot.tres` to a clearly labeled disposable training Resource, assign a unique ID, inspect exported fields, run validation in a temporary/sandbox context, then remove the training file.
- Provide a decision table: Resource edit, scene composition, existing-kind registration, or new behavior code.
- Cite [Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html), [Exported properties](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html), and [ResourceLoader](https://docs.godotengine.org/en/4.7/classes/class_resourceloader.html).

- [ ] **Step 3: Validate Task 2 terminology, source links, and code references**

Run:

```powershell
$taskFiles = @(
	'docs/handbook/03-typed-gdscript-signals-and-data-flow.md',
	'docs/handbook/04-resources-and-content-data.md'
)
$requiredSymbols = @(
	'class_name ClassDefinition',
	'signal member_added',
	'signal reward_dropped',
	'signal level_ready',
	'const CLASS_PATHS',
	'const TRAIT_PATHS',
	'const ENEMY_PATHS',
	'PARTY_FORGE_RESOURCE_ERROR'
)
$symbolFiles = Get-ChildItem scripts -Recurse -Filter *.gd
$requiredSymbols | ForEach-Object {
    if (-not ($symbolFiles | Select-String -SimpleMatch $_ -Quiet)) { throw "Missing referenced symbol: $_" }
}
$taskFiles | ForEach-Object {
    if (-not (Test-Path $_)) { throw "Missing handbook file: $_" }
	if (-not (Select-String -Path $_ -Pattern '> \*\*(Godot rule|Party Forge convention|Current limitation)' -Quiet)) { throw "Missing source classification callout: $_" }
	if (Select-String -Path $_ -Pattern 'TBD|TODO|fill in|implement later' -Quiet) { throw "Placeholder text: $_" }
}
git diff --check -- $taskFiles
```

Expected: no exceptions and no diff-check output.

- [ ] **Step 4: Commit the scripting and data chapters**

Run:

```powershell
git add -- docs/handbook/03-typed-gdscript-signals-and-data-flow.md docs/handbook/04-resources-and-content-data.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: explain Party Forge scripts and Resources"
```

Expected: exactly the two Task 2 files are staged and committed.

---

### Task 3: Existing Content and Class/Attack/Trait Recipes

**Files:**

- Create: `docs/handbook/05-modifying-existing-content.md`
- Create: `docs/handbook/06-adding-a-class-attack-and-trait.md`

**Interfaces:**

- Consumes: Task 2's Resource and data/behavior decision model.
- Produces: exact safe-edit and training-content recipes; Task 5 links these from the architecture checklist.

- [ ] **Step 1: Write the existing-content modification chapter**

Create `docs/handbook/05-modifying-existing-content.md` with these headings:

```markdown
# 5. Modifying Existing Party Forge Content Safely
## What you will learn
## Start with the owning Resource or script
## Class and formation values
## Attack values
## Trait tiers and supported effects
## Enemy values and script constants
## Party upgrades and spawn timing
## Exercise: make one reversible balance change
## Production recipe: tune, observe, and record a change
## Verification ladder
## Common mistakes
## Rollback
## Official Godot references
```

Required facts and examples:

- Provide a table mapping each editable field to its owning file/type and observable effect.
- Cover `ClassDefinition`: health, armor, move speed, rank step, revive settings, preferred/engagement/tether distances, primary/support actions.
- Cover `AttackDefinition`: kind, power, cooldown, range, projectile speed, and area radius; explain kind-specific validation.
- Cover `TraitDefinition`: supported `stat_id`, tiers, and Vanguard effect radius.
- Cover `EnemyDefinition`: health, speed, contact damage, and experience.
- Explicitly label Spitter preferred/retreat distance and fire interval, Swarmer contact range/cooldown, and the five-minute schedule bands as current script-owned constants rather than Resource fields.
- Cover `UpgradeTuning` and PartyManager party-stat ranks without implying Party Damage and healing are already separated.
- Exercise: record an existing value, make one modest reversible change in a Resource through the Inspector, save, run a focused sandbox observation, restore the original value, and confirm the diff disappears.
- Production recipe: change one value at a time, state the intended player-facing effect, collect an observation, and commit balance separately from structural content.
- Verification ladder: Resource validation → relevant unit suite → sandbox → ordinary run if pacing changed.

- [ ] **Step 2: Write the class, attack, and trait creation chapter with exact training data**

Create `docs/handbook/06-adding-a-class-attack-and-trait.md` with these headings:

```markdown
# 6. Adding a Class, Attack, and Trait
## What you will learn
## What can reuse current behavior
## Training example specification
## Step 1: create the training attack
## Step 2: create the training trait
## Step 3: create the recruit-only training class
## Step 4: validate in isolation
## Step 5: register for recruitment
## Optional production step: make the class a selectable leader
## When a class requires new behavior
## Tests and sandbox verification
## Common mistakes
## Rollback
## Official Godot references
```

Use this exact disposable training example so all instructions are concrete:

```text
Attack path: data/training/training_warden_bolt.tres
id: training_warden_bolt
kind: PROJECTILE
power: 10.0
cooldown: 1.0
range: 10.0
projectile_speed: 14.0
area_radius: 0.0

Trait path: data/training/training_focus.tres
id: training_focus
display_name: Training Focus
stat_id: attack_speed
tiers: {2: 0.10, 4: 0.25}
effect_radius: 0.0

Class path: data/training/training_warden.tres
id: training_warden
display_name: Training Warden
role: MIDLINE
color: #4f9dd9
traits: [training_focus, ranged]
max_health: 110.0
armor: 3.0
move_speed: 6.2
class_rank_power_step: 0.2
revive_delay: 8.0
revive_health_fraction: 0.5
preferred_distance: 4.5
engagement_distance: 10.0
tether_distance: 10.0
primary_attack: training_warden_bolt
support_action: empty
```

Required integration guidance:

- Create Resources in the Inspector using the registered custom Resource classes.
- Explain why the attack and trait satisfy current validation.
- For isolated validation, load the three training Resources in a temporary sandbox/test context without editing catalog constants.
- For the production-registration recipe, show the exact `GameCatalog.CLASS_PATHS` and `TRAIT_PATHS` arrays that require new entries.
- Explain that `LevelUpChoiceService.generate()` discovers registered classes and makes them recruits while party space remains.
- Explain duplicate recruitment can activate `training_focus` at two copies.
- For selectable leader status, list the exact additional integration points: `scenes/ui/hud.tscn` button, `PartyForgeMain._wire_static_ui()` class IDs/button path, and the corresponding main-wiring tests.
- Explain that new attack kinds, summons, auras, manual abilities, or new targeting policies require behavior code and focused tests.
- Rollback order: remove production registrations first, confirm the project parses, then remove disposable training Resources.
- Cite [Creating custom Resources](https://docs.godotengine.org/en/4.7/tutorials/scripting/resources.html#creating-your-own-resources), [Exported properties](https://docs.godotengine.org/en/4.7/tutorials/scripting/gdscript/gdscript_exports.html), and [Using signals](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/signals.html).

- [ ] **Step 3: Validate all documented fields and supported IDs against source**

Run:

```powershell
$taskFiles = @(
	'docs/handbook/05-modifying-existing-content.md',
    'docs/handbook/06-adding-a-class-attack-and-trait.md'
)
$sourceChecks = @{
	'scripts/data/class_definition.gd' = @('max_health', 'armor', 'preferred_distance', 'engagement_distance', 'tether_distance', 'primary_attack', 'support_action')
	'scripts/data/attack_definition.gd' = @('MELEE_CLEAVE', 'PROJECTILE', 'AREA_PROJECTILE', 'HEAL', 'projectile_speed', 'area_radius')
	'scripts/data/trait_definition.gd' = @('attack_speed', 'nearby_damage_reduction', 'projectile_speed_and_range', 'area_size', 'cooldown_reduction', 'healing_and_revive', 'support_power')
	'scripts/data/enemy_definition.gd' = @('max_health', 'move_speed', 'contact_damage', 'experience')
}
foreach ($file in $sourceChecks.Keys) {
	$text = Get-Content -Raw $file
	foreach ($needle in $sourceChecks[$file]) {
		if (-not $text.Contains($needle)) { throw "Documented field missing from $file: $needle" }
	}
}
$taskFiles | ForEach-Object {
	if (-not (Test-Path $_)) { throw "Missing handbook file: $_" }
	if (Select-String -Path $_ -Pattern 'TBD|TODO|fill in|implement later' -Quiet) { throw "Placeholder text: $_" }
}
git diff --check -- $taskFiles
```

Expected: all source facts exist and no diff errors are reported.

- [ ] **Step 4: Commit the content recipes**

Run:

```powershell
git add -- docs/handbook/05-modifying-existing-content.md docs/handbook/06-adding-a-class-attack-and-trait.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: add Party Forge content recipes"
```

Expected: exactly the two Task 3 files are committed.

---

### Task 4: Enemy Content and Presentation Workflows

**Files:**

- Create: `docs/handbook/07-adding-an-enemy.md`
- Create: `docs/handbook/08-visuals-audio-effects-and-ui.md`

**Interfaces:**

- Consumes: Task 1 scene composition and Task 2 data/behavior boundaries.
- Produces: enemy extension and AV/UI integration procedures used by the final architecture reference.

- [ ] **Step 1: Write the enemy chapter with existing-behavior and new-behavior tracks**

Create `docs/handbook/07-adding-an-enemy.md` with these headings:

```markdown
# 7. Adding an Enemy
## What you will learn
## The EnemyActor contract
## Current enemy data and behavior split
## Training Brute specification
## Track A: sandbox an enemy using Swarmer behavior
## Track B: register an enemy for production spawning
## Track C: implement genuinely new behavior
## Health, teams, targeting, rewards, and transient effects
## Tests and sandbox verification
## Common mistakes
## Rollback
## Official Godot references
```

Use this exact disposable data example:

```text
Resource path: data/training/training_brute.tres
id: training_brute
behavior: SWARMER
max_health: 40.0
move_speed: 3.5
contact_damage: 12.0
experience: 5
```

Required facts and guidance:

- Explain the `EnemyActor` base contract: `HealthComponent`, hostile group/team, `configure()`, `receive_damage()`, combat target, one reward, and defeat cleanup.
- Track A: create a disposable Resource and a training scene based on `swarmer.tscn`, assign the training definition, spawn it only in the combat sandbox, and observe movement/damage/reward behavior.
- State clearly that `EnemyDefinition.behavior = SWARMER` does not dynamically choose a script; the scene's attached script provides behavior.
- Track B: map current production changes required in `GameCatalog.ENEMY_PATHS`, `SpawnDirector` accepted IDs, scene selection, `SpawnSchedule`, sandbox actions, and tests.
- Explain why the current schedule's explicit Swarmer/Spitter weights mean a third weighted enemy is a behavior/architecture change, not merely new data.
- Track C: describe creating a focused script/scene, reusing `EnemyActor`, implementing movement/attack decisions, assigning groups and effects, and adding deterministic behavior tests.
- Explain hostile projectiles and telegraphs must join `hostile_transient_effects` so terminal/sandbox cleanup can find them.
- Cite [CharacterBody3D](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html), [Collision shapes 3D](https://docs.godotengine.org/en/4.7/tutorials/physics/collision_shapes_3d.html), [Groups](https://docs.godotengine.org/en/4.7/tutorials/scripting/groups.html), and [Scene organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/scene_organization.html).

- [ ] **Step 2: Write the visuals, audio, effects, and UI chapter**

Create `docs/handbook/08-visuals-audio-effects-and-ui.md` with these headings:

```markdown
# 8. Visuals, Audio, Effects, and UI
## What you will learn
## Source assets, imported Resources, and wrapper scenes
## Replacing a placeholder model safely
## Materials and per-instance changes
## Collision is separate from visible geometry
## Effects and lifetime ownership
## Positional and non-positional audio
## UI scenes, containers, anchors, and logical resolution
## Exercise: replace presentation without changing combat
## Production checklist
## Verification
## Common mistakes
## Rollback and reimport safety
## Official Godot references
```

Required facts and guidance:

- Recommend glTF 2.0 for manually authored 3D scene exchange while acknowledging other supported formats.
- Explain placing source assets inside the project, automatic import, the Import dock, `.import` metadata, and regenerable `.godot/imported/` data.
- Use wrapper or inherited scenes for imported models so collision, scripts, health, targeting, and effects remain game-owned and survive reimport.
- For actor replacement, preserve the scripted root and required `HealthComponent`, `AttackController`, collision, mesh/presentation child, and health-bar contract.
- Explain duplicating a material before a per-instance runtime color change; do not present shared Resource mutation as harmless.
- Explain collision shapes should match gameplay needs, not blindly mirror detailed rendering meshes.
- Explain effect ownership and cleanup; name the `Effects` container and hostile transient group.
- Use `AudioStreamPlayer3D` for positional attacks/enemies and `AudioStreamPlayer` for UI/music; explain `stream`, volume, pitch, bus, and listener/camera relationship without inventing a Party Forge bus layout.
- Link `../development/RESPONSIVE_UI_TUTORIAL.md`; summarize anchors, containers, 1920×1080 logical resolution, `canvas_items`, and `keep` aspect behavior without duplicating its instructions.
- Exercise: replace only a training/sandbox mesh or material, compare the actor's collision and behavior before/after, then revert.
- Cite [Importing 3D scenes](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html), [Introduction to 3D](https://docs.godotengine.org/en/4.7/tutorials/3d/introduction_to_3d.html), [AudioStreamPlayer3D](https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer3d.html), [AudioStreamPlayer](https://docs.godotengine.org/en/4.7/classes/class_audiostreamplayer.html), and [Multiple resolutions](https://docs.godotengine.org/en/4.7/tutorials/rendering/multiple_resolutions.html).

- [ ] **Step 3: Validate enemy/presentation claims against scenes and source**

Run:

```powershell
$taskFiles = @(
	'docs/handbook/07-adding-an-enemy.md',
	'docs/handbook/08-visuals-audio-effects-and-ui.md'
)
$requiredPaths = @(
	'scripts/enemies/enemy_actor.gd',
	'scripts/enemies/swarmer.gd',
	'scripts/enemies/spitter.gd',
	'scripts/game/spawn_director.gd',
	'scripts/game/spawn_schedule.gd',
	'scenes/enemies/swarmer.tscn',
	'scenes/enemies/spitter.tscn',
	'scenes/dev/combat_sandbox.tscn',
	'docs/development/RESPONSIVE_UI_TUTORIAL.md'
)
$requiredPaths | ForEach-Object {
    if (-not (Test-Path $_)) { throw "Broken documented path: $_" }
}
$spawnText = Get-Content -Raw 'scripts/game/spawn_director.gd'
foreach ($needle in @('swarmer', 'spitter', 'SWARMER_SCENE', 'SPITTER_SCENE')) {
    if (-not $spawnText.Contains($needle)) { throw "SpawnDirector fact missing: $needle" }
}
$taskFiles | ForEach-Object {
    if (-not (Test-Path $_)) { throw "Missing handbook file: $_" }
	if (Select-String -Path $_ -Pattern 'TBD|TODO|fill in|implement later' -Quiet) { throw "Placeholder text: $_" }
}
git diff --check -- $taskFiles
```

Expected: every path/fact exists and diff hygiene is clean.

- [ ] **Step 4: Commit the enemy and presentation chapters**

Run:

```powershell
git add -- docs/handbook/07-adding-an-enemy.md docs/handbook/08-visuals-audio-effects-and-ui.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: document enemies and presentation workflows"
```

Expected: exactly the two Task 4 files are committed.

---

### Task 5: Debugging, Testing, Architecture Reference, and Full Handbook Validation

**Files:**

- Create: `docs/handbook/09-debugging-testing-saving-and-git.md`
- Create: `docs/handbook/10-party-forge-architecture-reference.md`
- Modify: `docs/handbook/README.md`

**Interfaces:**

- Consumes: all earlier handbook chapters, the complete current repository map, custom test runner, and official Godot debugging documentation.
- Produces: operational troubleshooting workflow, durable architecture reference, complete navigation, and final handbook validation evidence.

- [ ] **Step 1: Write the debugging, testing, saving, and Git chapter**

Create `docs/handbook/09-debugging-testing-saving-and-git.md` with these headings:

```markdown
# 9. Debugging, Testing, Saving, and Git
## What you will learn
## Read the symptom before changing code
## Output, Debugger, breakpoints, and the Remote scene tree
## F1 and the class reference
## Party Forge validation layers
## Running the test suite
## Parser and import validation
## What Godot saves and generates
## Reading Git status and diffs
## Exercise: diagnose a safe deliberate failure
## Symptom-to-owner troubleshooting table
## Recovery without destroying unrelated work
## Official Godot references
```

Required facts and procedures:

- Explain Output versus Debugger Errors, breakpoints, stack frames, and Local versus Remote scene trees.
- Explain `F1` class search and the difference between conceptual manual pages and API class reference pages.
- List Party Forge validation layers: definition `validate()`, catalog validation, unit suites, parser/import initialization, combat sandbox, and ordinary run.
- Include the exact PowerShell full-suite command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

- Include the exact parser/import command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
```

- Explain success markers and the bounded scan-thread shutdown warning without classifying arbitrary warnings as successes.
- Explain Git `M`, `??`, staged versus unstaged state, `git diff`, `git diff --cached`, and `git diff --check`.
- Teach exact-file recovery first; do not recommend destructive broad resets.
- Deliberate failure exercise: temporarily give a disposable training Resource an empty ID, run validation, locate the grep-friendly error, restore the ID, and verify the error disappears.
- Provide a symptom table for invisible asset, unchanged balance, parse error, missing node, invalid Resource, UI drift, import mismatch, and wrong scene being run.
- Cite [Debug tools](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/index.html), [Output panel](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/output_panel.html), [Debugger panel](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/debugger_panel.html), and [Learning new features](https://docs.godotengine.org/en/4.7/getting_started/introduction/learning_new_features.html).

- [ ] **Step 2: Write the Party Forge architecture reference**

Create `docs/handbook/10-party-forge-architecture-reference.md` with these headings:

```markdown
# 10. Party Forge Architecture Reference
## How to use this reference
## Top-level project map
## Runtime scene tree
## System ownership table
## Content definition table
## Main run data flow
## Class and party flow
## Combat flow
## Enemy and reward flow
## Level-up flow
## Explicit registries and current limitations
## Change-owner decision table
## Verification checklist by change type
## Glossary
## Official Godot references
```

Required architecture content:

- Top-level map: `data/`, `scenes/`, `scripts/`, `tests/`, `tools/`, `docs/`, and `project.godot`.
- System ownership table covering `PartyForgeMain`, `GameRun`, `PartyManager`, `ExperienceSystem`, `SpawnDirector`, `PartyActorSpawner`, `PartyActor`, `AttackController`, `AttackExecutor`, `HealthComponent`, and HUD panels.
- Content table covering `ClassDefinition`, `AttackDefinition`, `TraitDefinition`, `EnemyDefinition`, and `UpgradeTuning` with exact file locations.
- Runtime flow diagrams expressed as ordered Markdown lists so they render in any viewer.
- Explicit limitations: catalog arrays, four leader UI buttons/callback IDs, current attack kinds, supported trait stat IDs, two regular SpawnDirector IDs/scenes, and two-weight SpawnSchedule.
- Change-owner decision table with at least: tune a number, add existing-kind attack, add recruit-only class, make class leader-selectable, add supported trait, add new trait effect, add existing-behavior enemy, add new behavior, replace a model, add positional sound, change UI layout, and alter run timing.
- Verification checklist mapping each change category to validation, focused test, sandbox, parser/import, and ordinary run requirements.
- Glossary including Node, scene, instance, Resource, signal, method, Inspector, SceneTree, Local, Remote, autoload distinction, `res://`, `.tscn`, `.tres`, `.gd`, `.uid`, `.import`, group, collision layer/mask, and typed GDScript.
- Cite the official pages already introduced in the handbook rather than adding unverified community sources.

- [ ] **Step 3: Finish README navigation and add task-oriented quick links**

Modify `docs/handbook/README.md` so that:

- every numbered chapter link resolves;
- `Learning path` lists chapters 1–10 in order;
- `Reference path` links directly to “modify existing content,” “add class/attack/trait,” “add enemy,” “visuals/audio/UI,” “debugging/testing/Git,” and “architecture reference”;
- the responsive UI tutorial link resolves;
- the version header still states architecture commit `a293f62`, Godot `4.7.1`, and date `2026-07-29`.

- [ ] **Step 4: Run the complete local handbook audit**

Run:

```powershell
$handbookFiles = @(
	'docs/handbook/README.md',
	'docs/handbook/01-editor-and-project-files.md',
	'docs/handbook/02-nodes-scenes-and-instances.md',
	'docs/handbook/03-typed-gdscript-signals-and-data-flow.md',
	'docs/handbook/04-resources-and-content-data.md',
	'docs/handbook/05-modifying-existing-content.md',
	'docs/handbook/06-adding-a-class-attack-and-trait.md',
	'docs/handbook/07-adding-an-enemy.md',
	'docs/handbook/08-visuals-audio-effects-and-ui.md',
	'docs/handbook/09-debugging-testing-saving-and-git.md',
	'docs/handbook/10-party-forge-architecture-reference.md'
)
$handbookFiles | ForEach-Object {
    if (-not (Test-Path $_)) { throw "Missing handbook file: $_" }
    if ((Get-Content $_).Count -lt 40) { throw "Suspiciously short handbook file: $_" }
	if (Select-String -Path $_ -Pattern 'TBD|TODO|fill in|implement later|replace this text' -Quiet) { throw "Placeholder text: $_" }
}
$relativeLinks = Get-ChildItem docs/handbook -Filter *.md | ForEach-Object {
    $source = $_
	Select-String -Path $_.FullName -Pattern '\]\((?!https?://|#)([^)]+\.md)(#[^)]+)?\)' -AllMatches | ForEach-Object {
        foreach ($match in $_.Matches) {
            [pscustomobject]@{ Source = $source.FullName; Target = $match.Groups[1].Value }
        }
    }
}
foreach ($link in $relativeLinks) {
    $targetPath = Join-Path (Split-Path $link.Source) $link.Target
    if (-not (Test-Path $targetPath)) { throw "Broken relative link in $($link.Source): $($link.Target)" }
}
git diff --check -- docs/handbook
```

Expected: all eleven documents exist, every relative Markdown document link resolves, no placeholder is found, and diff hygiene is clean.

- [ ] **Step 5: Validate every official Godot link resolves**

Run:

```powershell
$officialLinks = Get-ChildItem docs/handbook -Filter *.md | ForEach-Object {
	Select-String -Path $_.FullName -Pattern 'https://docs\.godotengine\.org/[^)\s]+' -AllMatches | ForEach-Object {
        $_.Matches.Value
    }
} | Sort-Object -Unique
foreach ($url in $officialLinks) {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $url -MaximumRedirection 5 -TimeoutSec 30
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
        throw "Official Godot link failed ($($response.StatusCode)): $url"
    }
    "GODOT_LINK_OK $url"
}
```

Expected: every unique official link prints `GODOT_LINK_OK`; no community tutorial is used as authority for engine behavior.

- [ ] **Step 6: Run Party Forge tests and parser/import validation**

Run:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
git diff --check
```

Expected: `TEST_SUMMARY: PASS (16 suites)`, both Godot commands exit `0`, parser/import initialization reaches `[ DONE ]`, and diff check reports no errors. If Godot regenerates an untracked `.uid`, leave any pre-existing user file untouched and remove only a newly generated file whose absence was recorded before this task.

- [ ] **Step 7: Self-review the handbook against the design success criteria**

Confirm each statement is answered by a specific chapter and record the chapter in the task report:

```text
The reader can explain Node vs scene vs script vs Resource.
The reader can locate authoritative class, attack, trait, enemy, and UI data.
The reader can modify and verify an existing content value.
The reader can create and validate the Training Warden content in isolation.
The reader can list every required production registration step.
The reader can distinguish existing behavior from new behavior code.
The reader can import and wrap a model without losing gameplay nodes.
The reader can use Output, Debugger, Remote, tests, and Git status.
The reader can safely undo every exercise.
The reader can reach official Godot documentation from every conceptual chapter.
```

Expected: no success criterion relies only on unstated prior knowledge or another unlinked document.

- [ ] **Step 8: Commit the operational chapters and final navigation**

Run:

```powershell
git add -- docs/handbook/README.md docs/handbook/09-debugging-testing-saving-and-git.md docs/handbook/10-party-forge-architecture-reference.md
git diff --cached --check
git diff --cached --name-only
git commit -m "docs: complete Party Forge Godot handbook"
```

Expected: exactly the three Task 5 files are committed. `git status --short` still shows only the user's pre-existing unrelated modifications and untracked work.
