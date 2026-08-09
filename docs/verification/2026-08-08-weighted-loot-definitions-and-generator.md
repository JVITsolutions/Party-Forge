# Weighted Loot Definitions and Deterministic Generator Verification

Verified 2026-08-09 in the isolated worktree on branch `docs/weighted-loot-generation-design`.

## Scope and commits

- Branch starting documentation commit: `7b423c5`.
- Task 8 verification base: `2dd63f4`.
- Increment implementation commits before this verification record: `0716794`, `0d916a9`, `15af030`, `e9a4c19`, `cc79d51`, `64795cc`, `afb325c`, `de6cfb6`, `f012d12`, `c9578a8`, `b8e410b`, `4d865e8`, and `2dd63f4`.
- Task 8 commit subject: `test: verify deterministic weighted loot generation`.
- Godot: `4.7.1.stable.official.a13da4feb`.

Task 8 adds startup cross-catalog validation against all 99 live equipment bases and bounded deterministic distribution coverage. Its distribution suite makes stage selections only; it does not call `ItemInstanceIssuer`, place an item, or mutate a profile, run, container, save, or ownership record.

## TDD evidence

The cross-catalog test was added before its production validation. Its first focused run exited 1 with `TEST_SUMMARY: FAIL (5 failures)`. The five expected missing contracts were:

- unknown equipment implicit references;
- an ordinary pattern whose declared affix kind had no live candidate;
- an affix whose tiers were all outside item level `1..1000`;
- an ordinary-enabled rarity above rank 5;
- propagation of cross-catalog errors through `GameCatalog`.

The existing validation already rejected the other three injected fixtures: impossible affix tags, ordinary-enabled rarities without reachable patterns, and duplicate external manifest paths. A separate wrong-kind implicit RED run exited 1 with the expected missing kind check.

The distribution test was also observed RED before its golden values were recorded. It produced exactly these stable hashes:

- 5,000 complete base/rarity/pattern/affix/tier stage selections: `2eee553b990823f87038db64aac90ce02a844e6da16bddeb19d4bd76ed3ce044`.
- 5,000 high-item-level tier selections: `876b63e583cb4b3b67a495b7f96b372075e7e533bdbea7e3ce0246c0d023b57a`.

The GREEN distribution suite replays both batches and audits every selected base, rarity, pattern, affix, modifier family, tier, effect, and roll against its hard gates. It also verifies directional item-level scaling, improving but diminishing Charisma rare-family selection, the exact base-selection smart-loot behavior, and preservation of off-party drops.

## Required verification

Executable used by all commands:

```powershell
$godot = 'C:\Users\Jacob\AppData\Local\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.1-stable_win64_console.exe'
```

### Import

```powershell
& $godot --headless --path . --import
```

- Exit: `0`.
- Duration: `4.580s` measured inside PowerShell after live smart-loot archetype authoring.
- Forbidden diagnostic count for `SCRIPT ERROR`, `Parse Error`, `No loader found`, failed-resource text, and failed resource loads: `0`.

### Focused Increment 1 batch

```powershell
& $godot --headless --path . --quit-after 240 --script res://tests/focused_test_runner.gd -- tests/unit/test_item_generation_definitions.gd tests/unit/test_item_foundation_manifest.gd tests/unit/test_item_generation_request.gd tests/unit/test_item_base_and_rarity_selection.gd tests/unit/test_item_affix_assembler.gd tests/unit/test_item_generation_service.gd tests/unit/test_item_generation_distribution.gd tests/unit/test_item_foundation_catalog.gd tests/unit/test_item_instance_codec.gd tests/unit/test_game_catalog.gd
```

- Exit: `0`.
- Duration: `12.340s` after live smart-loot archetype authoring.
- Exact summary: `TEST_SUMMARY: PASS (0 failures)` once.
- `TEST_FAILURE` count: `0`.

### Complete project suite

```powershell
& $godot --headless --path . --quit-after 420 --script res://tests/test_runner.gd
```

- Exit: `0`.
- Duration: `108.380s` after live smart-loot archetype authoring.
- Exact summary: `TEST_SUMMARY: PASS (156 suites)` once.
- `TEST_FAILURE` count: `0`.
- Script/parse/loader error count: `0`.
- The suite continued to emit intentional negative-path `PARTY_FORGE_*_ERROR` records from their enclosing passing tests.
- Shutdown continued to report the known cleanup diagnostics: 18 leaked `ObjectDB` instances and 5 resources still in use. These occur after the one explicit passing summary and are not new loader, parser, or test failures.

### Startup smoke test

```powershell
& $godot --headless --path . --quit-after 10
```

- Exit: `0`.
- Duration: `1.785s` after live smart-loot archetype authoring.
- `PARTY_FORGE_BOOT_OK`: exactly once.
- `PARTY_FORGE_CLASS_SELECTION_READY`: exactly once.
- Script/parse/loader/resource-load error count: `0`.

## Repository scope

The following checks were run before staging:

```powershell
git diff --check
git status --short
git diff --stat main...HEAD
```

`git diff --check` produced no findings. The initial Task 8 commit contained these planned paths:

- `scripts/items/item_foundation_catalog.gd`
- `tests/unit/test_game_catalog.gd`
- `tests/unit/test_item_generation_distribution.gd`
- `docs/verification/2026-08-08-weighted-loot-definitions-and-generator.md`

`scripts/data/game_catalog.gd` already passed `equipment_catalog` into foundation validation in the prior manifest work, so Task 8 required no additional edit there. No profile data, user save, `.godot` cache, or `.gd.uid` sidecar is part of the change. Generated UID sidecars remain untracked and deliberately untouched.

## Final review corrections

Final review identified three reachability/vocabulary gaps and one distribution assertion gap. The follow-up corrects them without production drop or placement wiring:

- Reachability now solves one complete pattern scenario on one base and one domain/source pair. Base implicits seed the same blocked-definition and blocked-family state used by prefix, suffix, and special slots. Candidate IDs are lexically ordered, failed states are memoized, and the default 10,000-state exploration budget fails closed with `reason=reachability exploration budget exhausted`.
- Regression fixtures prove rejection of cross-kind family conflicts, implicit/explicit family conflicts, kinds that are individually feasible only on different bases, incompatible domain/source routes, and an exhausted exploration budget.
- `known_item_tags` is the manifest-backed canonical vocabulary for generation filters. It now exactly equals the union of all live `normalized_generation_tags()`, including explicit generation tags, eligibility tags, item types, weight classes, and weapon families. Request base/affix filters validate against the same registry.
- `ItemFoundationCatalog.generation_unlock_tags()` is the Increment 1 unlock vocabulary. Its source is the union of rarity and affix `required_unlock_tags` authored in the item foundation manifest. A later progression increment may replace or cross-check it against a global progression registry; Increment 1 intentionally has no separate progression registry.
- An end-to-end service regression proves an unlock-gated affix is rejected before issuance without its tag and generated when that manifest tag is supplied.
- Charisma distribution now separately proves `rate_1000 > rate_100 > rate_0` and that the marginal gain from 100 to 1000 is smaller than the gain from 0 to 100. Both exact replay hashes remained unchanged.

The review-fix commit adds only the canonical manifest, foundation/request contracts, their focused tests, and this verification record. No schema, ownership, issuer sequence, profile, save, cache, UID, or production-wiring file is included.

## Live smart-loot archetype authoring

Final live-data review found that the smart-loot policy and synthetic tests were correct, but none of the 99 live equipment bases authored a class-identity `generation_tags` value. A live-catalog regression was written first and observed RED with `TEST_SUMMARY: FAIL (104 failures)`: all 99 resources lacked their expected directory identity, the normalized union lacked `melee`, the representative Fighter base remained at 1.0x, request validation rejected `required_base_tags = [&"melee"]`, and live melee selection had no eligible candidates.

The data correction authors exactly one explicit class identity on every live base, based on its equipment-set directory rather than inferring from a broad `martial` tag:

- melee: Dawn Bulwark, Forge Vanguard, and Nightstep (`34` bases);
- ranged: Greenwood and Siege Archer (`22` bases);
- caster: Emberweave, Grave Covenant, Rime Scholar, and Storm Chaplain (`43` bases).

A mechanical audit found exactly `99` tag lines and zero directory/tag mismatches. Unrestricted bases continue to gain `global` through `normalized_generation_tags()`, so the exact live normalized union now includes `melee`, `ranged`, `caster`, and `global`. The canonical `known_item_tags` manifest was updated with `melee`.

The regression reads `GameCatalog.EQUIPMENT_CATALOG`, proves every catalogued resource path maps to its expected set and exact authored identity, proves a representative live melee base receives the exact 3.0x multiplier, proves live off-party and global-capable bases retain positive authored weight, and proves a validated `required_base_tags = [&"melee"]` request exposes exactly the 34 live melee candidates. Its GREEN rerun was `TEST_SUMMARY: PASS (0 failures)`.

The required focused batch retained both deterministic replay hashes unchanged. This follow-up changes only the 99 equipment base resources, the canonical item-foundation manifest, the live regression, and this verification record; no script, UID, profile/save, or cache file is included.

## Deferred items assessed

- Exotic, Ascendant, and Divine palette authoring is presentation work and does not affect generator acceptance.
- Rejecting arbitrary unsupported trace `Variant` values and normalized-key collisions remains a trace-hardening follow-up; this increment records only JSON-like stable trace data.
- Null-safe selector sorting for deliberately malformed in-memory catalogs remains deferred. Startup validation rejects malformed production catalogs before generation, and the deterministic selector/distribution acceptance path uses validated non-null definitions.

Increment 1 deliberately does not add production drop wiring, equipment-stat application, production-scale affix content, Loot Lab UI, profiles, saves, or container placement.
