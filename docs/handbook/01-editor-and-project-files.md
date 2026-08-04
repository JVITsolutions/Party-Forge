# 1. The Godot Editor and Party Forge Project Files

> **Architecture baseline:** `a293f6208bd3a62246043c1b3e7c0a49ad5fef73`<br>
> **Godot version:** `4.7.1`<br>
> **Last checked:** `2026-08-04`

## What you will learn

- Identify the editor areas needed to inspect Party Forge.
- Translate a `res://` path into a repository file without embedding a machine-specific absolute path.
- Tell source files and versioned import metadata from regenerable cache files.
- Run the project or current scene, stop it, and verify that an inspection-only exercise changed nothing.

## The editor areas you will use

Godot divides one editor window into workspaces, docks, and bottom panels. If your layout differs, use **Editor > Editor Docks** to restore or show a dock.

- **Scene dock:** shows the node tree for the currently open scene. Selecting a node here makes it available in the Inspector.
- **FileSystem dock:** shows files Godot recognizes under `res://`. Use it to open Party Forge scenes, scripts, Resources, and source assets.
- **Inspector dock:** shows editable properties for the selected node or Resource. Prefer this over hand-editing `.tscn` or `.tres` text.
- **Output panel:** shows text printed by the editor or running game. Party Forge boot checkpoints such as `PARTY_FORGE_BOOT_OK` appear here.
- **Debugger panel:** collects runtime errors, stack traces, breakpoints, and performance information. A red error belongs here even if the game window stays open.
- **2D workspace:** edits two-dimensional nodes and `Control`-based interfaces.
- **3D workspace:** edits `Node3D` scenes such as `scenes/characters/companion.tscn` and `scenes/arena/arena.tscn`.
- **Script workspace:** reads and edits `.gd` scripts and provides the built-in class reference.
- **Game workspace:** displays the running project inside the editor when embedded play is enabled. A separate game window may appear instead, depending on editor settings.

> **Godot rule:** A selected node appears in the Scene dock, while its editable properties appear in the Inspector. The editor is fundamentally a scene editor; it also provides 2D, 3D, UI, script, output, and debugging tools.

## What `res://` means

`res://` is Godot's portable name for the project root: the directory that contains `project.godot`. In this repository, that is the Party Forge directory.

Examples:

- `res://project.godot` maps to `project.godot` at the repository root.
- `res://scenes/game/main.tscn` maps to `scenes/game/main.tscn`.
- `res://scripts/game/main.gd` maps to `scripts/game/main.gd`.

Use `res://` paths inside scenes, scripts, and Resources. A local Windows checkout path helps you navigate your own computer, but it is not portable project data and must not be saved into Party Forge files.

> **Godot rule:** The `res://` prefix means “resource path” and points to the directory containing `project.godot`.

## Party Forge file types

| File or directory | Meaning | Party Forge example | Version-control expectation |
|---|---|---|---|
| `.tscn` | Text scene: a saved node tree with one root. | `scenes/game/main.tscn` | Track intentional edits. |
| `.tres` | Text Resource: saved data that is not itself a node tree. | `data/classes/fighter.tres` | Track intentional edits. |
| `.gd` | GDScript source attached to nodes or used as reusable logic/data types. | `scripts/game/main.gd` | Track intentional edits. |
| `.uid` | A small editor-generated sidecar that associates a source file with a stable resource UID. | `scripts/game/main.gd.uid` | Keep generated tracked sidecars; do not hand-edit them. |
| Source asset | The original image, audio, font, or model placed in the project. | `icon.svg` | Track approved source assets. |
| `.import` | Import settings stored beside a non-native source asset. | `icon.svg.import` | Track it with its source asset. |
| `.godot/` | Editor state and generated import/cache data. | `.godot/imported/` | Regenerable; do not commit it. |
| `project.godot` | Project-wide settings, feature version, input actions, and the main-scene path. | `project.godot` | Track intentional settings changes. |

> **Godot rule:** Godot writes import configuration to `<asset>.import` and internal imported data under `.godot/imported/`. The `.import` metadata belongs in version control; the `.godot/` cache can be regenerated.

> **Party Forge convention:** Folder and file names use lowercase `snake_case`, while node names such as `PartyActorSpawner` and `HealthComponent` use `PascalCase`. This also avoids case-only path failures on exported builds.

## What saving actually saves

There is no single monolithic “save project” file containing Party Forge.

- Saving an open scene writes that scene's `.tscn` file.
- Saving an external Resource writes that Resource's `.tres` file.
- Saving a script writes its `.gd` file.
- Changing Project Settings writes `project.godot` when those settings are saved.
- Inspector edits to a built-in subresource are stored in the owning scene or Resource; Inspector edits to an external Resource are stored in that external file.

Pressing `Ctrl+S` saves the active editor context, not every unsaved item everywhere. Look for unsaved markers on scene and script tabs, then check `git status --short` to see what reached disk.

> **Checkpoint:** Before closing Godot, you can name which `.tscn`, `.tres`, `.gd`, or `project.godot` file should contain each intended change.

## F5, F6, and F8

- `F5` runs the configured project main scene. Party Forge's `project.godot` points to `res://scenes/game/main.tscn`.
- `F6` runs the scene currently open in the editor. Use it for focused scenes such as `res://scenes/dev/combat_sandbox.tscn`.
- `F8` stops the running project or scene and returns control to the editor.

> **Godot rule:** Running the current scene and running the project main scene are different operations. Check which one you started when the result is surprising.

## Imported versus generated files

When a supported source asset enters the project, Godot imports it automatically. The original file stays in the project, a neighboring `.import` file records its import options, and processed cache files go under `res://.godot/imported/`.

If `.godot/imported/` is absent after a fresh checkout, Godot rebuilds it. Do not treat that rebuild as an authored content change. By contrast, a changed `.import` file can alter texture, audio, or model behavior on every machine, so review and commit it when the import setting change is intentional.

`.uid` files are also generated by the editor, but they serve stable resource references. If opening Godot creates a new `.uid`, inspect whether it belongs to a newly added tracked script before deciding its scope; never edit the UID text by hand.

## Exercise: inspect the project without changing it

This exercise is read-only. Its expected changed-file list is empty.

1. Press `Ctrl+S`, then press `F8` if anything is running.
2. At the repository root, record:

   ```powershell
   git status --short
   ```

3. In the FileSystem dock, locate `res://project.godot`. Open it through **Project > Project Settings** for the editor view; do not change a setting.
4. Locate `res://scenes/game/main.tscn`. Double-click it and inspect its Scene tree.
5. Locate `res://data/classes/fighter.tres`. Select it and read its fields in the Inspector without typing.
6. Locate `res://scripts/game/main.gd`. Open it in the Script workspace and find `class_name PartyForgeMain` without editing.
7. Press `F5`. Confirm the functional main menu appears first and the Output panel includes `PARTY_FORGE_BOOT_OK` and `PARTY_FORGE_CLASS_SELECTION_READY`. The second marker means the reusable run-setup selector is configured; it does not mean class selection is the boot screen.
8. Press `F8`.
9. Run `git status --short` again and compare it line for line with step 2.

> **Checkpoint:** The same pre-existing paths appear before and after. No new or modified file was caused by this inspection-only exercise.

If a `.uid` or cache file appears after the first editor scan, do not stage it automatically. Identify whether it is newly generated, whether Git tracks that file type at that path, and whether it belongs to the exercise's expected scope.

## Production habit: predict the changed files

Before editing, write a tiny change contract:

```text
Goal: adjust the Fighter display name
Expected authored file: data/classes/fighter.tres
Expected generated files: none
Files that must not change: project.godot, scenes/game/main.tscn
```

Then edit through the Inspector, press `Ctrl+S`, and compare the contract with `git status --short` and `git diff -- <path>`. This habit catches accidental scene serialization and Project Settings edits before they mix with useful work.

> **Party Forge convention:** Treat scene files, scripts, data Resources, and generated/import metadata as separate review scopes even when Godot updates more than one during a session.

## Verification

For this chapter, success is observable:

- `F5` starts `scenes/game/main.tscn` and reaches the functional main menu before Profiles or class selection.
- The Output panel contains both Party Forge boot messages.
- `F8` stops the run.
- The before-and-after `git status --short` output matches.
- You can point to `project.godot`, `scenes/game/main.tscn`, `data/classes/fighter.tres`, and `scripts/game/main.gd` in the FileSystem dock.

Do not continue if the editor reports a parse error, the main scene is not the one expected, or Git shows an unexplained authored file.

## Common mistakes

- **“I pressed F6 and Party Forge did not start.”** F6 ran the currently open scene. Open `scenes/game/main.tscn` or use F5.
- **“A file exists in Windows Explorer but not the FileSystem dock.”** Wait for the filesystem scan; also check whether a parent folder contains `.gdignore`.
- **“The game runs, so the red Debugger entry is harmless.”** A running window is not a clean result. Read the first error and its stack trace.
- **“I changed a `.tres`, but Git shows a `.tscn`.”** You may have edited a built-in Resource owned by the scene rather than the external file you intended. Inspect the Resource path in the Inspector.
- **“I deleted `.godot/` and broke the project.”** Reopen the project and allow Godot to reimport. The cache is regenerable; the process can take time.
- **“Git shows a changed `.import` file.”** Select the source asset, inspect the Import dock, and decide whether its options were intentionally changed before keeping it.

## How to undo an accidental editor change

1. Stop the running scene with `F8`.
2. If the edit is still unsaved, use Godot's **Undo** (`Ctrl+Z`) in the same scene or Inspector context.
3. If you understand the exact unsaved scope, close that scene or Resource tab and choose not to save it.
4. Run `git status --short` and `git diff -- <exact-path>` to verify what remains on disk.
5. If the change was already saved and you cannot isolate it safely, stop and ask for help. Preserve unrelated work.

Never use `git reset --hard` as a beginner rollback step. It can destroy changes outside the mistake you intended to undo.

> **Checkpoint:** Rollback is complete only when the exact unwanted diff is gone and all unrelated pre-existing changes remain.

## Official Godot references

- [Nodes and scenes](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/nodes_and_scenes.html)
- [Project organization](https://docs.godotengine.org/en/4.7/tutorials/best_practices/project_organization.html)
- [Import process](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/import_process.html)
