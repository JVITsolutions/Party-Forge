# Party Forge Godot Handbook

> **Initial architecture baseline:** Chapters 1–2 and 8–9 at `a293f6208bd3a62246043c1b3e7c0a49ad5fef73`<br>
> **Nine-class runtime architecture:** Chapters 3–6 and 10 at `b0be05a03bbd3ea5aae04d3e38ffdc0769a211ba`<br>
> **Typed-combat enemy tutorial architecture:** Chapter 7 at `97f05b5fa77d8447830bb2a42209b83140384e6b`<br>
> **Handbook wording alignment:** Chapter 7 at `9f1b9bbb5cdc04374b3288ada07eb8081032a188`<br>
> **Godot version:** `4.7.1`

## Who this is for

This handbook is for someone who wants to understand and safely change Party Forge but has no prior Godot knowledge. Basic programming ideas will be introduced when they become useful. Follow the numbered chapters in order on your first pass; later, use individual chapters as references.

## How to use the handbook

The learning path is hybrid:

1. Chapters 1–4 build the editor, scene, script, signal, and Resource vocabulary used by the rest of the project.
2. Chapters 5–8 turn that vocabulary into focused content and presentation workflows.
3. Chapters 9–10 become operational references for debugging, Git safety, and architecture.

Read the explanation, inspect the exact Party Forge paths, perform the exercise, and stop at every **Checkpoint**. If your result differs, use the chapter's troubleshooting section before moving on.

Practice in `scenes/dev/` or another explicitly disposable sandbox before changing a production scene or data file. Apply a sandbox lesson to production only when the intended game design is approved and you can name the files that should change.

> **Current limitation:** Review provenance is scoped by chapter rather than claimed for the handbook as a single snapshot. The commit named in each chapter banner is the immutable architecture source; **Last checked** is maintenance context, not proof of a source snapshot. Recheck file paths and behavior when the project architecture or Godot version changes.

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

The numbered learning path is complete. Follow it in order on a first pass, then use the task-oriented links below.

## Reference path

- Use [Modifying Existing Party Forge Content Safely](05-modifying-existing-content.md) to tune an existing class, attack, trait, enemy, upgrade, or spawn value.
- Use [Adding a Class, Attack, and Trait](06-adding-a-class-attack-and-trait.md) for the Training Warden exercise and production registration steps.
- Use [Adding an Enemy](07-adding-an-enemy.md) to reuse existing enemy behavior or plan a new behavior script.
- Use [Visuals, Audio, Effects, and UI](08-visuals-audio-effects-and-ui.md) for imports, wrapper scenes, materials, collision, effects, and audio.
- Use [Debugging, Testing, Saving, and Git](09-debugging-testing-saving-and-git.md) when behavior differs from a checkpoint or repository state is unclear.
- Use [Party Forge Architecture Reference](10-party-forge-architecture-reference.md) when you need an owner, registry, runtime flow, verification checklist, or glossary term.
- Use the existing [Party Forge Responsive UI Tutorial](../development/RESPONSIVE_UI_TUTORIAL.md) for anchors, offsets, resizing centered panels, and responsive-layout verification. This handbook links to that focused tutorial instead of repeating it.

## Callout labels

> **Godot rule:** Engine behavior supported by an official Godot reference.

> **Party Forge convention:** A repository-specific choice, accompanied by a file path or symbol you can inspect.

> **Current limitation:** A restriction in the implementation at that chapter's named architecture commit; it may change later. The **Last checked** date records when the guidance was reviewed, not which code it describes.

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
