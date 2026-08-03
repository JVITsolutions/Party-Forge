# Forward Attack Windups Validation

## Scope

This change corrects attack windups that moved character arms and equipped items behind the torso. It covers both body variants and all ten authored attacks: Fighter, Paladin, Ranger, Marksman, Rogue, Mage, Frost Mage, Cleric lightning, Cleric healing, and Warlock.

Verified implementation commit: `0204925a0f59a01195afd44536a2d7b5cd08b07d`.

## Root cause and regression test

The previous quality test checked attack endpoints but did not constrain intermediate windup poses. Several loaded shoulder and elbow rotations therefore pulled hands and equipment behind the body.

The new regression test samples every attack at 21 evenly spaced points, for masculine and feminine bodies, and checks the left hand, right hand, left elbow, and right elbow independently. The normal hand depth limit is `z <= 0.18`, the bow draw-hand allowance is `z <= 0.26`, and the elbow limit is `z <= 0.14`.

The new test was witnessed failing before the animation change:

- Exit: `1`
- Failures: `318`
- Fighter right hand reached `z=0.447`
- Paladin right hand reached `z=0.485`

After reauthoring the class-specific windups, the focused test passed with zero failures. A separate RED/GREEN contract test also verified that the visual-QA renderer clears obsolete PNG samples before rendering.

## Exact-candidate verification

The implementation commit was verified in its isolated worktree with a fresh Godot import:

- Godot import exit: `0`
- Full unit suite: `TEST_SUMMARY: PASS (96 suites)`
- Unit failures: `0`
- Script errors: `0`
- Presentation smoke: `PARTY_FORGE_PLAYABLE_PRESENTATION_SMOKE_OK classes=9 bodies=2 slots=11 items=99 icons=198 animations=21 projectiles=6 effects=5`
- Locomotion smoke: `PARTY_FORGE_LOCOMOTION_SMOKE_OK directions=4 walk=1 idle=1 smooth_turn=1 attack_lock=1 equipment_independent=1 grounding=1 shadow=1`
- Visual smoke: `PARTY_FORGE_CHARACTER_VISUAL_QA_SMOKE_OK classes=9 bodies=2 combinations=18 grounding=18 shadows=18 bars=18 equipment=18 actions=18 projectiles=1`

The shared humanoid scene was rebuilt twice with no drift. Its SHA-256 was:

`22D66051FF0D13FEDAF263F31DFB44377F8B6C8C2E17BDE4FA596D7972D91EF8`

## Hardware visual QA

Godot 4.7.1 Forward+ rendered the suite on an NVIDIA RTX 4070 Ti SUPER:

`PARTY_FORGE_CHARACTER_VISUAL_QA_OK classes=9 bodies=2 views=4 state_samples=20`

The output was deterministic across consecutive renders:

- Manifest rows: `360`
- Frame PNGs: `360`
- Contact sheets: `18`
- Total PNGs: `378`
- Changed files on second render: `0`
- Removed files on second render: `0`
- Dimension errors: `0`
- Zero-byte PNGs: `0`
- Loaded-pose depth violations: `0`

Maximum loaded-pose joint depths were:

- Left hand: `-0.220223367214203`
- Right hand: `-0.232186794281006`
- Left elbow: `-0.0323735177516937`
- Right elbow: `-0.0314910411834717`

Both Fighter loaded/release close-ups and all 18 class/body contact sheets were visually reviewed. The Fighter chambers the sword beside the shield, the Paladin raises the hammer forward, bows draw across the front, Rogue daggers stay forward, and caster implements remain in front of the torso. Masculine and feminine variants are consistent.

Representative frames:

- `docs/qa/character-presentation-quality/fighter/masculine/19_attack_loaded_close.png`
- `docs/qa/character-presentation-quality/fighter/masculine/20_attack_release_close.png`

## Repository hygiene

The final tracked tree passed `git diff --check` and was clean. Godot-generated `.import` sidecars were removed from the commit, leaving zero tracked visual-QA import sidecars. Verification-created untracked import/cache files were not staged.

Automated pose geometry and rendered evidence pass. A live gameplay feel check remains useful for subjective timing, but is not an outstanding automated failure.
