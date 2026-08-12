# Party Forge
> Party Forge is an early-development 3D party-survival action RPG prototype built with Godot 4.7.1.

## Current prototype

Choose an archetypal leader and enter an arena where the leader moves under player control. Recruited party members follow the leader, choose targets, and fight automatically while the party grows through run-based class, trait, and stat choices.

This repository is a working prototype, not a finished game. Its systems, content, and presentation are still being developed and may change.

## Implemented foundations

- Arena combat with a player-controlled leader, automatically fighting companions, enemy spawning, experience, and run results.
- Class and party progression through recruitment, class ranks, traits, upgrades, and party stats.
- A Character Ledger for inspecting party members, stats, current upgrades, equipment, and run inventory.
- Profiles, settings, feature-access policies, and explicit developer-mode gates.
- Typed stat, damage, modifier, and upgrade definitions with validation.
- Item generation, stable item ownership, inventory containers, equipment assignment, and equipment comparison.
- Personal manual ground loot with owner-aware visibility, selection, pickup, inventory-capacity handling, and run-lifecycle cleanup.
- Responsive UI foundations for the ledger, equipment, inventory, Armoury, Warehouse, and shared item tooltips.
- Automated controller-input coverage for supported menu, ledger, equipment, tooltip, and ground-loot flows. This coverage uses simulated input; physical-controller and manual visual acceptance remain separate work.

## Controls

| Action | Keyboard and mouse | Controller |
|---|---|---|
| Move leader | `W`, `A`, `S`, `D` | Left stick |
| Open or close Character Ledger | `I` or `Tab` | Left shoulder |
| Pause or resume a run | `Esc` | Menu button |
| Inspect and pick up ground items | Hover to inspect; left-click to request pickup | D-pad left/right selects; south face button requests pickup |
| Move equipment or inventory items | Drag and drop between supported slots | West face button picks up or releases the focused item; move focus, then use the south face button to place or confirm |

When a supported item tooltip is visible, hold `Alt` for equipment comparison and `Shift` for advanced affix details. Use the tooltip's visible pin control, or the controller north face button, where that control is offered. Tooltip behavior is context-sensitive, and some details or actions are available only in the relevant Character Ledger, Armoury, Warehouse, or ground-loot view.

## Requirements

- [Git](https://git-scm.com/) to clone the repository.
- [Godot 4.7.1](https://docs.godotengine.org/en/4.7/). The automated-test example below uses the Windows .NET/Mono console executable.
- PowerShell to run the example test command on Windows.

## Clone and run

Private-repository collaborators must authenticate with GitHub before cloning, for example through GitHub Desktop or a configured Git credential manager.

```powershell
git clone https://github.com/JVITsolutions/Party-Forge.git
cd Party-Forge
```

Open the Godot Project Manager, choose **Import**, select the repository's `project.godot`, and import the project. Open it in Godot 4.7.1, then choose **Run Project** or press `F5`.

## Run the automated tests

From the repository root, point PowerShell at your Godot 4.7.1 console executable and run the complete unit-test suite:

```powershell
$godot = 'C:\path\to\Godot_v4.7.1-stable_mono_win64_console.exe'
& $godot --headless --path . --quit-after 1800 --script res://tests/test_runner.gd
```

A successful run ends with a `TEST_SUMMARY: PASS` marker. Some negative-path suites intentionally emit structured diagnostic output, so use the final summary and process exit code when judging the run.

Specialized integration and acceptance runners provide additional automated coverage and are not invoked by this command. Their commands and accepted evidence are documented in the [current verification report](docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md).

## Project documentation

- [Party Forge Godot Handbook](docs/handbook/README.md) — the guided learning path and architecture reference.
- [Responsive UI Tutorial](docs/development/RESPONSIVE_UI_TUTORIAL.md) — layout concepts and project-specific UI guidance.
- [Live Personal Loot and Equipment Ledger Verification](docs/verification/2026-08-11-live-personal-loot-and-equipment-ledger.md) — accepted automated evidence and explicitly deferred manual checks for the current feature milestone.
- [Godot 4.7 documentation](https://docs.godotengine.org/en/4.7/) — engine documentation for the project version.

## Development status

Party Forge remains in early development. Final balance, art, and audio; campaign/adventure mode; extraction and trading gameplay; split-screen and online multiplayer; broader meta-progression; and commercial-release polish remain under development.

The linked verification report records the accepted automated evidence for the current personal-loot and equipment-ledger milestone. It also identifies manual visual review and physical-controller acceptance as deferred; automated coverage should not be read as completion of those checks.

## License

No repository-wide license is currently provided. Source code and assets remain copyright their respective owners, and publication of this repository does not grant permission to copy, modify, redistribute, or reuse them. Obtain an explicit license from the relevant rights holder before any third-party reuse.
