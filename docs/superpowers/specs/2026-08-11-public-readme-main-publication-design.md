# Party Forge Public README and Main Publication Design

**Status:** Approved design pending written-spec review  
**Date:** 2026-08-11

## Goal

Publish the completed live personal-loot and equipment-ledger increment to the existing GitHub `main` branch without losing newer mainline work, then make the repository understandable and honest to a first-time visitor.

## Integration

- Fetch and compare local `main`, `origin/main`, and `feat/live-personal-loot` immediately before integration.
- Preserve the newer swarmer-rat commits already on `main`.
- Merge `feat/live-personal-loot` into `main`; resolve only genuine overlaps and retain both intended behaviors.
- Do not rewrite history or force-push.
- Verify the merged tree before pushing `main` to `origin`.
- Remove the completed feature worktree and local feature branch only after merge, verification, and push succeed.

## Root README

Add `README.md` at the repository root. It will:

- identify Party Forge as an active, early-development Godot prototype rather than a finished or production-ready game;
- describe the Brotato/Vampire Survivors-inspired party-following combat premise in original Party Forge terms;
- summarize currently implemented systems without presenting planned features as complete;
- list the primary keyboard/mouse and controller inputs that are currently wired;
- state the required editor version: Godot 4.7.1, with the project currently using Forward Plus;
- provide clone, import, run, and headless-test instructions using portable placeholders instead of machine-specific paths;
- link to the handbook, current verification report, development tutorials, and license/status section;
- state that screenshots, final art, balance, online multiplayer, split-screen, campaign/adventure mode, extraction, trading, and other roadmap features remain in development where applicable;
- avoid unsupported release dates, platform promises, or claims that deferred manual testing has passed.

## Stale Repository Audit

The audit will target current repository usability, not historical evidence. It will check:

- Git remote/branch synchronization and ahead/behind state;
- root documentation links and current Godot entrypoints;
- tracked temporary/generated/cache/import files;
- secrets or machine-specific runtime configuration;
- obvious stale present-tense status statements in current entrypoint documentation;
- README-referenced controls, scenes, scripts, and test commands against the merged tree.

Historical verification reports may retain absolute paths and past environment details because those are evidence of how prior validation was run. Existing branches, worktrees, assets, and QA evidence will not be deleted merely because they are old.

## Verification and Push Gate

Before push:

1. Run `git diff --check` and confirm a clean merge state.
2. Validate every README path/link and documented input action against the merged tree.
3. Run the complete Godot test suite in isolated `APPDATA` and `LOCALAPPDATA` roots.
4. Require process exit `0`, exactly one passing test summary, and no parser, script, loader, or leak markers.
5. Run the project boot/readiness smoke check.
6. Confirm the final commit contains only intended merge, README, and bounded stale-correction changes.
7. Push `main` normally to `origin` and verify local `main` equals `origin/main` afterward.

Manual visual review and physical-controller acceptance remain explicit deferred gates unless performed separately; they will not be relabeled as automated passes.
