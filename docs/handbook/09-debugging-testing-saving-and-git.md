# 9. Debugging, Testing, Saving, and Git

> **Handbook version:** Party Forge architecture verified at `a293f62`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-07-29`

## What you will learn

- Begin with an observed symptom and preserve its exact evidence.
- Use Output, Debugger, breakpoints, stack frames, and the Remote scene tree.
- Choose the narrowest Party Forge validation layer that can expose a problem.
- Distinguish source files you save from metadata and caches Godot generates.
- Read staged and unstaged Git state without discarding unrelated work.
- Introduce, diagnose, and restore one safe validation failure.

## Read the symptom before changing code

Do not start by guessing a fix. First write one sentence describing the difference between expected and observed behavior. Include the scene you ran, the action you took, and the first exact error message or visible mismatch.

Use this order:

1. Reproduce once with the smallest relevant scene or test.
2. Copy the first error, including its file, line, and grep-friendly Party Forge prefix when present.
3. Record `git status --short` before editing.
4. Identify the likely owner: data, scene composition, behavior script, registry, import settings, UI layout, or run state.
5. Inspect that owner and its inputs before changing anything.
6. Make one reversible change, rerun the same reproduction, and compare the result.

Later errors may be consequences of the first failure. Fixing the final line in a cascade often hides the cause without repairing it.

> **Party Forge convention:** Runtime and validation errors use searchable prefixes such as `PARTY_FORGE_RESOURCE_ERROR`, `PARTY_FORGE_ENEMY_HEALTH_MISSING`, and `PARTY_FORGE_UNKNOWN_ENEMY_ID`. Copy the complete message before clearing Output.

## Output, Debugger, breakpoints, and the Remote scene tree

The **Output** panel shows text printed by the editor and running project. Use it for boot markers, test summaries, deliberate `print()` messages, warnings, and errors. Its filters can hide categories, so clear a filter before concluding that a message never appeared.

The **Debugger** panel's **Errors** tab collects runtime errors and warnings. Its **Stack Trace** tab becomes especially useful when execution stops at a breakpoint or script error. A stack frame is one active method call. Read from the stopped frame outward to learn which caller supplied the bad value.

To set a breakpoint, click the gutter beside a script line. Run the relevant scene and reproduce the symptom. When execution pauses:

1. Confirm the highlighted line is on the path you expected.
2. Select stack frames to inspect how execution arrived there.
3. Inspect local variables, parameters, and member values.
4. Use **Step Over** to advance without entering a called method, **Step Into** to follow the next call, and **Continue** to resume.
5. Remove or skip the breakpoint when finished so an old pause does not look like a freeze later.

The Scene dock has two views while a project runs:

- **Local** is the editor-side scene tree currently open for editing, including changes that may not have been saved yet.
- **Remote** is the live SceneTree. It includes runtime-spawned leaders, companions, enemies, projectiles, health bars, and experience orbs that do not exist in the saved scene.

Use Remote when a node is missing, duplicated, under the wrong parent, in the wrong group, or carrying an unexpected runtime value. For Party Forge, inspect `Actors`, `Enemies`, and `Effects`, then select the live node and read its Remote Inspector values.

> **Godot rule:** A running scene is an instance tree. The Local tree is not proof of which nodes currently exist at runtime.

## F1 and the class reference

Press **F1** or choose **Help > Search Help** to search the built-in class reference. Search for an engine type such as `CharacterBody3D`, `Resource`, `Signal`, or `CollisionShape3D`. A class-reference page lists inheritance, properties, methods, signals, enums, and constants.

Use the conceptual manual when you need to learn *why* or *when* to use a feature, such as scene organization, Resources, debugging, or multiple resolutions. Use the class reference when you need the exact API contract for one class, property, or method. Class pages often link back to relevant conceptual manual pages.

In the script editor, hold **Ctrl** and click a recognized engine symbol to open its reference. For Party Forge classes, use **Ctrl+click**, Find in Files, or the script path because repository classes are documented by their source rather than an engine class page.

## Party Forge validation layers

No single check proves every kind of change. Move through these layers from narrow to broad:

1. **Definition validation:** `ClassDefinition`, `AttackDefinition`, `TraitDefinition`, `EnemyDefinition`, and `UpgradeTuning` expose `validate()` for their supported structural rules.
2. **Catalog validation:** `GameCatalog.validate()` loads the explicitly registered class, trait, and enemy Resources, rejects failed loads and duplicate IDs, and prefixes definition failures.
3. **Unit suites:** `tests/test_runner.gd` discovers every `tests/unit/test_*.gd` script and runs its `run()` method. Suites cover definitions, party state, progression, combat, spawning, wiring, UI layout, and run states.
4. **Parser/import initialization:** a headless editor start parses scripts and scenes, refreshes class information, and initializes imports. This catches failures that a narrow unit may not load.
5. **Combat sandbox:** `scenes/dev/combat_sandbox.tscn` exposes controlled party, enemy, boss, damage, reward, and cleanup observations.
6. **Ordinary run:** the main scene verifies real pacing, random choices, UI transitions, five-minute spawning, boss entry, victory, and defeat.

> **Current limitation:** A passing definition validator proves only the rules implemented in that validator. It does not prove registration, behavior, presentation, balance, or game feel.

## Running the test suite

From PowerShell, run the complete suite with this exact command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://tests/test_runner.gd
```

At the verified architecture, success requires both:

- process exit code `0`;
- `TEST_SUMMARY: PASS (16 suites)` in the output.

On failure, the runner prints `TEST_FAILURE: <suite path> :: <assertion>` and exits `1`. Start with the first failure and run or inspect that focused suite before changing production code. A timeout, closed terminal, partial suite list, or absence of a failure message is not a pass.

The runner discovers suites by filename. A new test must live in `tests/unit/`, begin with `test_`, end with `.gd`, and implement `func run() -> Array[String]`.

## Parser and import validation

Run a separate bounded editor initialization:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --editor --quit-after 2
```

Success requires exit code `0`, completed `[ DONE ]` initialization markers, and no parse, missing dependency, or import error. The command is bounded to two seconds. On a machine where shutdown interrupts an otherwise completed background scan, Godot may print `Scan thread aborted`; record that warning alongside the completed markers and exit code. Do not reinterpret arbitrary warnings as harmless: an error naming your script, scene, Resource, or import still requires investigation.

If another editor instance is already open, a remote-debugger or editor port-bind warning can appear even when this command exits `0` and reaches the required markers. Record the exact warning and corroborating success evidence. Close the other editor and rerun when you need to determine whether the warning is environmental.

> **Checkpoint:** Unit tests and parser/import initialization are separate evidence. Record both exit codes and their markers.

## What Godot saves and generates

Godot saves different kinds of project state to different files:

| File or directory | Meaning | Treatment |
| --- | --- | --- |
| `project.godot` | Project settings, main scene, input, rendering, and display configuration | Review and commit intentional changes |
| `.tscn` | Text scene composition, node properties, connections, and Resource links | Save and review as source |
| `.tres` | Text Resource data | Save and review as source |
| `.gd` | GDScript source | Save and review as source |
| `.uid` | Godot identity sidecar used by Resource references | Do not delete or commit blindly; compare with repository state |
| `.import` | Per-source-asset import metadata | Keep with an intentional imported source asset |
| `.godot/imported/` | Regenerable imported cache | Do not edit by hand or treat as source truth |
| `.godot/` editor data | Local caches and editor state | Normally ignored and regenerated |

**Ctrl+S** saves the active scene, script, or Resource. Use **Save All** when several editor tabs contain intentional changes. Saving a scene does not automatically mean every external Resource you edited was saved; check the unsaved indicator and Git status.

Before and after any headless editor run, record whether an unexpected `.uid` exists. Remove only a newly generated, previously absent disposable UID after recording it. Preserve tracked and pre-existing files.

## Reading Git status and diffs

Run these from the repository root:

```powershell
git status --short
git diff -- path/to/file
git diff --cached -- path/to/file
git diff --check
```

Short status uses two columns before the path:

- ` M path` means the tracked file has an unstaged modification.
- `M  path` means a modification is staged.
- `MM path` means the file has staged content plus a newer unstaged change.
- `?? path` means Git does not track the file.

`git diff` shows unstaged changes. `git diff --cached` shows what the next commit would contain. `git diff --check` reports whitespace errors; no output with exit code zero is the successful result.

> **Party Forge convention:** Stage explicit paths and verify `git diff --cached --name-only` before every documentation or content commit.

## Exercise: diagnose a safe deliberate failure

This exercise creates a disposable enemy definition and validator. It does not register or alter production content.

1. Record `git status --short`. Confirm the following disposable paths do not already contain someone else's work.
2. Duplicate `res://data/enemies/swarmer.tres` as `res://data/training/debug_enemy.tres` in the FileSystem dock.
3. Set its ID to `debug_enemy`, save, and leave its other valid values unchanged.
4. Create `res://scripts/dev/debug_resource_validation.gd`:

```gdscript
extends SceneTree

const RESOURCE_PATH := "res://data/training/debug_enemy.tres"

func _init() -> void:
    var definition := load(RESOURCE_PATH) as EnemyDefinition
    if definition == null:
        push_error("PARTY_FORGE_RESOURCE_ERROR path=%s reason=load failed" % RESOURCE_PATH)
        quit(1)
        return
    var failures := definition.validate()
    for reason: String in failures:
        push_error("PARTY_FORGE_RESOURCE_ERROR path=%s reason=%s" % [RESOURCE_PATH, reason])
    if failures.is_empty():
        print("PARTY_FORGE_RESOURCE_VALID path=%s" % RESOURCE_PATH)
        quit(0)
    else:
        quit(1)
```

5. Run it from the repository root:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path 'F:\Projects(root)\Game dev\Projects\party-forge' --script res://scripts/dev/debug_resource_validation.gd
```

6. Confirm exit code `0` and `PARTY_FORGE_RESOURCE_VALID`.
7. In the Inspector, set the disposable Resource's ID to an empty value and save. Run the same command again.
8. Confirm exit code `1` and copy the grep-friendly error: `PARTY_FORGE_RESOURCE_ERROR path=res://data/training/debug_enemy.tres reason=enemy id is empty`.
9. Restore the ID to `debug_enemy`, save, and rerun. Confirm exit code `0`, the valid marker returns, and the error is absent.
10. Delete exactly the two disposable files through Godot, plus only their newly generated UID files. Remove `data/training/` only if it is empty and you created it.
11. Compare `git status --short` with the initial record. Search for `debug_enemy`; no exercise reference should remain.

> **Checkpoint:** You proved the failure was caused by one field, restored that field, and returned the repository to its starting state.

## Symptom-to-owner troubleshooting table

| Symptom | First evidence | Likely owner | First focused check |
| --- | --- | --- | --- |
| Imported asset is invisible | Remote tree, visibility, transform, camera view | Import settings or wrapper presentation child | Reimport, open wrapper, reset child transform, keep gameplay root unchanged |
| Balance value appears unchanged | Inspector path and Resource reference | Owning definition or script constant | Confirm the running instance references the edited external `.tres`; check Chapter 5's owner table |
| Parse error | First Output/Debugger file and line | `.gd`, `.tscn`, or `.tres` syntax/reference | Open the first named file, correct one syntax error, rerun parser initialization |
| Missing node error | Exact node path plus Local/Remote tree | Scene composition or runtime spawner | Compare required name and parent in the saved scene and live tree |
| Invalid Resource | `PARTY_FORGE_RESOURCE_ERROR` reason | Definition values, links, or `GameCatalog` registration | Call the definition validator, then catalog validation |
| UI drifts at another resolution | Screenshot and viewport size | Anchors, offsets, Container, or logical-resolution settings | Follow the responsive UI tutorial and its three-size matrix |
| Imported result differs from source | Import dock and wrapper after reimport | Source asset, `.import` settings, or inherited overrides | Reimport, reopen wrapper, inspect overrides; never edit `.godot/imported/` |
| Wrong scene is running | Remote root and editor tab | F5 main scene versus F6 current scene | Use F5 for `project.godot`'s main scene or open the intended sandbox before F6 |

## Recovery without destroying unrelated work

Recover the smallest known unit:

1. Stop the running project and record current status.
2. Inspect `git diff -- exact/path` before restoring anything.
3. If the change is a single Inspector field, type back the recorded original value and save.
4. If a staged file should remain edited but not staged, use `git restore --staged -- exact/path`; this leaves the working copy intact.
5. Delete an untracked file only when its exact path is disposable, its absence was recorded before the exercise, and it contains no unrelated work.
6. Rerun the narrow reproduction, then `git diff --check` and `git status --short`.

Do not use `git reset --hard`, broad `git restore .`, or `git clean -fd` as troubleshooting shortcuts. They can destroy other work that has nothing to do with the symptom. If an exact tracked file contains mixed changes, restore your field or hunk manually instead of discarding the file.

## Official Godot references

- [Debug tools](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/index.html)
- [Output panel](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/output_panel.html)
- [Debugger panel](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/debugger_panel.html)
- [Learning new features](https://docs.godotengine.org/en/4.7/getting_started/introduction/learning_new_features.html)
