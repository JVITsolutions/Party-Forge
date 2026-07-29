# Party Forge Godot Handbook

> **Verified architecture commit:** `a293f62`<br>
> **Godot version:** `4.7.1`<br>
> **Initial check date:** `2026-07-29`

## Who this is for

This handbook is for someone who wants to understand and safely change Party Forge but has no prior Godot knowledge. Basic programming ideas will be introduced when they become useful. Follow the numbered chapters in order on your first pass; later, use individual chapters as references.

## How to use the handbook

The learning path is hybrid:

1. Chapters 1–4 build the editor, scene, script, signal, and Resource vocabulary used by the rest of the project.
2. Chapters 5–8 turn that vocabulary into focused content and presentation workflows.
3. Chapters 9–10 become operational references for debugging, Git safety, and architecture.

Read the explanation, inspect the exact Party Forge paths, perform the exercise, and stop at every **Checkpoint**. If your result differs, use the chapter's troubleshooting section before moving on.

Practice in `scenes/dev/` or another explicitly disposable sandbox before changing a production scene or data file. Apply a sandbox lesson to production only when the intended game design is approved and you can name the files that should change.

> **Current limitation:** The handbook is verified against architecture commit `a293f62` and Godot `4.7.1`. Recheck file paths and behavior when either changes.

## Before every exercise

1. Press `Ctrl+S` in Godot to save the scene, script, or Resource you intend to keep.
2. Stop the running game with `F8` when an exercise needs editor changes or a clean rerun.
3. From the Party Forge repository root, run:

   ```powershell
   git status --short
   ```

4. Write down the exact files you expect the exercise to change. If `git status --short` later shows another path, stop and inspect it before saving, staging, or committing.

> **Checkpoint:** You know the starting Git status and can name the expected changed files before editing.

## Learning path

1. [The Godot Editor and Party Forge Project Files](01-editor-and-project-files.md)
2. [Nodes, Scenes, and Instances](02-nodes-scenes-and-instances.md)
3. [Typed GDScript, Signals, and Data Flow](03-typed-gdscript-signals-and-data-flow.md)
4. [Resources and Content Data](04-resources-and-content-data.md)
5. [Modifying Existing Content](05-modifying-existing-content.md)
6. [Adding a Class, Attack, and Trait](06-adding-a-class-attack-and-trait.md)
7. [Adding an Enemy](07-adding-an-enemy.md)
8. [Visuals, Audio, Effects, and UI](08-visuals-audio-effects-and-ui.md)
9. [Debugging, Testing, Saving, and Git](09-debugging-testing-saving-and-git.md)
10. [Party Forge Architecture Reference](10-party-forge-architecture-reference.md)

Chapters 3–10 are linked now so this page remains the stable table of contents while the handbook is built in batches.

## Reference path

- Use [Party Forge Architecture Reference](10-party-forge-architecture-reference.md) when you already know the concept and need the owning file, registry, or data flow.
- Use [Debugging, Testing, Saving, and Git](09-debugging-testing-saving-and-git.md) when behavior differs from a checkpoint.
- Use the existing [Party Forge Responsive UI Tutorial](../development/RESPONSIVE_UI_TUTORIAL.md) for anchors, offsets, resizing centered panels, and responsive-layout verification. This handbook links to that focused tutorial instead of repeating it.

## Callout labels

> **Godot rule:** Engine behavior supported by an official Godot reference.

> **Party Forge convention:** A repository-specific choice, accompanied by a file path or symbol you can inspect.

> **Current limitation:** A restriction in the implementation verified at `a293f62`; it may change later.

> **Checkpoint:** An observable result you must verify before continuing.

These labels separate engine behavior from this project's choices. A Party Forge convention is not automatically a rule for every Godot project.

## What this handbook will not do

- It will not redesign Party Forge while explaining it.
- It will not replace the official Godot manual or class reference.
- It will not duplicate the responsive UI tutorial.
- It will not ask you to learn by editing production files first.
- It will not treat a successful launch as proof that every affected system is correct; each chapter defines narrower checkpoints.

Example classes, enemies, visuals, values, and names used for training are disposable practice content. They must not be mistaken for approved Party Forge design or shipped merely because an exercise works.

## Official Godot starting points

These links point to the Godot 4.7 manual used for this handbook:

- [Step by step](https://docs.godotengine.org/en/4.7/getting_started/step_by_step/index.html) — the official beginner sequence for nodes, scenes, scripts, input, and signals.
- [Learning new features](https://docs.godotengine.org/en/4.7/getting_started/introduction/learning_new_features.html) — how to use the manual, class reference, and editor help.
- [Tutorials](https://docs.godotengine.org/en/4.7/tutorials/index.html) — topic-oriented guides for editor, assets, scripting, 3D, UI, and debugging.
