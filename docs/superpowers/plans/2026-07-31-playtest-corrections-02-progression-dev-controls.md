# Progression Offers and Developer Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce varied deterministic five-card level-up offers, implement approved recruit odds and drought protection, and add next-run XP/card-count developer controls.

**Architecture:** A run-owned `LevelUpOfferState` tracks offer sequence and eligible recruit drought. A stateless `RecruitOfferPolicy` maps a deterministic roll to the approved count. Settings and `RunRulesSnapshot` own next-run overrides; `ExperienceSystem` applies the snapshotted multiplier with fractional carry.

**Tech Stack:** Godot 4.7.1 Mono, typed GDScript, ConfigFile settings, Godot Control scenes, custom headless tests.

## Global Constraints

- Execute after Plan 01 passes.
- Production card count is five.
- Recruit distribution is exactly 45% zero, 40% one, 12% two, 3% three.
- After three consecutive eligible no-recruit offers, the next eligible offer contains at least one recruit.
- Full-party/ineligible offers neither increment nor clear the recruit drought.
- XP override range is 100%–1000%.
- Developer offer-count override range is 1–8, with five as the saved and production default.
- Player Simulation ignores developer overrides but retains their saved values.
- Overrides are snapshotted at run start; no active-run mutation is added.

---

### Task 1: Recruit Offer Policy and Run-Owned Offer State

**Files:**
- Create: `scripts/progression/recruit_offer_policy.gd`
- Create: `scripts/progression/level_up_offer_state.gd`
- Create: `tests/unit/test_recruit_offer_policy.gd`

**Interfaces:**
- Produces: `RecruitOfferPolicy.count_for_roll(roll: float, drought_streak: int) -> int`.
- Produces: `LevelUpOfferState.offer_sequence: int`.
- Produces: `LevelUpOfferState.consecutive_eligible_without_recruit: int`.
- Produces: `LevelUpOfferState.seed_for(run_seed: int, pending_level: int, party_size: int) -> int`.
- Produces: `LevelUpOfferState.record_recruit_result(eligible: bool, recruit_count: int) -> void`.

- [ ] **Step 1: Write failing boundary and drought tests**

Create `tests/unit/test_recruit_offer_policy.gd`:

```gdscript
extends RefCounted

func run() -> Array[String]:
	var failures: Array[String] = []
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.0, 0), 0, "roll starts zero-recruit band", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.449999, 0), 0, "zero-recruit band ends below 45 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.45, 0), 1, "one-recruit band begins at 45 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.849999, 0), 1, "one-recruit band ends below 85 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.85, 0), 2, "two-recruit band begins at 85 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.969999, 0), 2, "two-recruit band ends below 97 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.97, 0), 3, "three-recruit band begins at 97 percent", failures)
	TestAssertions.equal(RecruitOfferPolicy.count_for_roll(0.1, 3), 1, "three misses force one recruit", failures)
	var state := LevelUpOfferState.new()
	for _index: int in 3:
		state.record_recruit_result(true, 0)
	TestAssertions.equal(state.consecutive_eligible_without_recruit, 3, "eligible misses accumulate drought", failures)
	state.record_recruit_result(false, 0)
	TestAssertions.equal(state.consecutive_eligible_without_recruit, 3, "ineligible offer preserves drought", failures)
	state.record_recruit_result(true, 1)
	TestAssertions.equal(state.consecutive_eligible_without_recruit, 0, "recruit clears drought", failures)
	var first_seed := state.seed_for(1337, 2, 1)
	state.offer_sequence += 1
	TestAssertions.truthy(first_seed != state.seed_for(1337, 2, 1), "offer sequence changes seed", failures)
	TestAssertions.truthy(first_seed != LevelUpOfferState.new().seed_for(7331, 2, 1), "run seed changes offer seed", failures)
	return failures
```

- [ ] **Step 2: Run and verify missing classes fail**

Expected: load/parser failures name `RecruitOfferPolicy` and `LevelUpOfferState`.

- [ ] **Step 3: Implement the probability bands**

Create `scripts/progression/recruit_offer_policy.gd`:

```gdscript
class_name RecruitOfferPolicy
extends RefCounted

const DROUGHT_LIMIT := 3

static func count_for_roll(roll: float, drought_streak: int) -> int:
	var safe_roll := clampf(roll if is_finite(roll) else 0.0, 0.0, 0.999999)
	var count := 0
	if safe_roll >= 0.97:
		count = 3
	elif safe_roll >= 0.85:
		count = 2
	elif safe_roll >= 0.45:
		count = 1
	if drought_streak >= DROUGHT_LIMIT:
		count = maxi(count, 1)
	return count
```

Create `scripts/progression/level_up_offer_state.gd`:

```gdscript
class_name LevelUpOfferState
extends RefCounted

var offer_sequence := 0
var consecutive_eligible_without_recruit := 0

func seed_for(run_seed: int, pending_level: int, party_size: int) -> int:
	return hash("%d:%d:%d:%d" % [run_seed, offer_sequence, pending_level, party_size])

func record_recruit_result(eligible: bool, recruit_count: int) -> void:
	if not eligible:
		return
	if recruit_count > 0:
		consecutive_eligible_without_recruit = 0
	else:
		consecutive_eligible_without_recruit += 1
```

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/progression/recruit_offer_policy.gd scripts/progression/level_up_offer_state.gd tests/unit/test_recruit_offer_policy.gd
git commit -m "feat: add recruit offer distribution policy"
```

### Task 2: Configurable Unique Offer Generation

**Files:**
- Modify: `scripts/progression/level_up_choice_service.gd:1-145`
- Modify: `tests/unit/test_upgrade_choices.gd`
- Modify: `tests/unit/test_progression.gd`

**Interfaces:**
- Changes: `LevelUpChoiceService.generate(party: PartyManager, catalog: GameCatalog, seed: int, offer_count: int = 5, offer_state: LevelUpOfferState = null) -> Array[UpgradeChoice]`.
- All internal append helpers receive `limit: int` rather than comparing with literal `3`.

- [ ] **Step 1: Replace guaranteed-recruit tests with policy acceptance tests**

Add cases that call `generate(..., 5, state)` and assert:

```gdscript
TestAssertions.equal(offer.size(), 5, "production offer contains five cards", failures)
TestAssertions.equal(_unique_count(offer), offer.size(), "offer keys are unique", failures)
TestAssertions.equal(_keys(repeat), _keys(offer), "same seed and equivalent pre-offer state reproduce offer", failures)
```

Construct `repeat` with a fresh `LevelUpOfferState` whose sequence and drought equal the first state's values before generation. Find deterministic seeds for 0/1/2/3 recruit bands by testing the policy roll separately, then assert generated recruit counts are clamped by party capacity and candidate variety. Add a state with drought `3` and a seed in the zero band; assert at least one recruit. Add a full party and assert its drought value is unchanged.

- [ ] **Step 2: Run and verify current fixed-three/guaranteed-one behavior fails**

Expected: current service returns three cards and always inserts one recruit when capacity exists.

- [ ] **Step 3: Implement bounded count and recruit sampling**

At the start of `generate`:

```gdscript
static func generate(
	party: PartyManager,
	catalog: GameCatalog,
	seed: int,
	offer_count: int = 5,
	offer_state: LevelUpOfferState = null
) -> Array[UpgradeChoice]:
	var chosen: Array[UpgradeChoice] = []
	if party == null:
		return chosen
	var limit := clampi(offer_count, 1, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var keys: Dictionary = {}
	var recruits := _recruit_candidates(party, catalog)
	var recruit_eligible := party.can_recruit() and not recruits.is_empty()
	var desired_recruits := 0
	if recruit_eligible:
		var drought := offer_state.consecutive_eligible_without_recruit if offer_state != null else 0
		desired_recruits = RecruitOfferPolicy.count_for_roll(rng.randf(), drought)
		desired_recruits = mini(desired_recruits, mini(limit, recruits.size()))
		while desired_recruits > 0 and not recruits.is_empty():
			var index := rng.randi_range(0, recruits.size() - 1)
			_append_choice(recruits[index], party, chosen, keys, limit)
			recruits.remove_at(index)
			desired_recruits -= 1
	if offer_state != null:
		offer_state.record_recruit_result(recruit_eligible, _kind_count(chosen, UpgradeChoice.Kind.RECRUIT))
```

Add the private counter:

```gdscript
static func _kind_count(choices: Array[UpgradeChoice], kind: UpgradeChoice.Kind) -> int:
	var count := 0
	for choice: UpgradeChoice in choices:
		if choice != null and choice.kind == kind:
			count += 1
	return count
```

Change every `chosen.size() < 3`, `chosen.size() >= 3`, and `_append_choice(...)` call to use the passed `limit`. The final party-stat fallback loop stops at `limit`.

- [ ] **Step 4: Run the offer suites and full suite**

Expected: five-card uniqueness, deterministic replay, recruit count, drought, and capacity tests pass.

- [ ] **Step 5: Commit generation behavior**

```powershell
git add -- scripts/progression/level_up_choice_service.gd tests/unit/test_upgrade_choices.gd tests/unit/test_progression.gd
git commit -m "feat: generate varied five-card level offers"
```

### Task 3: Persistent XP and Card-Count Developer Settings

**Files:**
- Modify: `scripts/settings/party_forge_settings.gd:1-33`
- Modify: `scripts/settings/party_forge_settings_store.gd:10-53`
- Modify: `scripts/game/run_rules_snapshot.gd:1-34`
- Modify: `tests/unit/test_party_forge_settings.gd`
- Modify: `tests/unit/test_run_rules_policies.gd`

**Interfaces:**
- Produces settings fields `experience_multiplier_percent: int`, `level_up_card_count: int`.
- Produces snapshot methods `experience_multiplier_percent() -> int`, `level_up_card_count() -> int`.

- [ ] **Step 1: Add failing normalization, persistence, and snapshot tests**

Assert defaults `100` and `5`, clamps `100..1000` and `1..8`, save/load round trip, copy isolation, Player Simulation values `100/5`, and Developer Mode snapshot retention after the saved object mutates.

- [ ] **Step 2: Add fields and normalization**

Add to `PartyForgeSettings`:

```gdscript
const MIN_EXPERIENCE_MULTIPLIER := 100
const MAX_EXPERIENCE_MULTIPLIER := 1000
const MIN_LEVEL_UP_CARD_COUNT := 1
const MAX_LEVEL_UP_CARD_COUNT := 8

var experience_multiplier_percent := 100
var level_up_card_count := 5
```

Add to `normalize()`:

```gdscript
experience_multiplier_percent = clampi(experience_multiplier_percent, MIN_EXPERIENCE_MULTIPLIER, MAX_EXPERIENCE_MULTIPLIER)
level_up_card_count = clampi(level_up_card_count, MIN_LEVEL_UP_CARD_COUNT, MAX_LEVEL_UP_CARD_COUNT)
```

Copy both fields in `copy()`.

- [ ] **Step 3: Persist fields with backward-compatible defaults**

Load:

```gdscript
var xp_value: Variant = config.get_value(SECTION, "experience_multiplier_percent", 100)
result.experience_multiplier_percent = int(xp_value) if typeof(xp_value) == TYPE_INT else 100
var cards_value: Variant = config.get_value(SECTION, "level_up_card_count", 5)
result.level_up_card_count = int(cards_value) if typeof(cards_value) == TYPE_INT else 5
```

Save:

```gdscript
config.set_value(SECTION, "experience_multiplier_percent", normalized.experience_multiplier_percent)
config.set_value(SECTION, "level_up_card_count", normalized.level_up_card_count)
```

Keep schema version `1`; missing keys intentionally load defaults.

- [ ] **Step 4: Snapshot only active Developer Mode values**

Add private snapshot fields defaulting to `100` and `5`, copy them only inside the existing developer-mode block, and add:

```gdscript
func experience_multiplier_percent() -> int: return _experience_multiplier_percent
func level_up_card_count() -> int: return _level_up_card_count
```

- [ ] **Step 5: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/settings/party_forge_settings.gd scripts/settings/party_forge_settings_store.gd scripts/game/run_rules_snapshot.gd tests/unit/test_party_forge_settings.gd tests/unit/test_run_rules_policies.gd
git commit -m "feat: persist progression developer overrides"
```

### Task 4: Fractional XP Multiplier Runtime

**Files:**
- Modify: `scripts/progression/experience_system.gd:1-32`
- Modify: `scripts/game/main.gd:64-100`
- Modify: `tests/unit/test_progression.gd`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Produces: `ExperienceSystem.configure_multiplier(percent: int) -> void`.
- Produces: `ExperienceSystem.fractional_experience: float` for deterministic inspection.

- [ ] **Step 1: Add failing fractional-carry tests**

```gdscript
var boosted := ExperienceSystem.new()
boosted.configure_multiplier(150)
boosted.add_experience(1)
TestAssertions.equal(boosted.experience, 1, "first 150 percent award grants whole XP", failures)
TestAssertions.near(boosted.fractional_experience, 0.5, 0.001, "first award carries half XP", failures)
boosted.add_experience(1)
TestAssertions.equal(boosted.experience, 3, "second award consumes carried fraction", failures)
TestAssertions.near(boosted.fractional_experience, 0.0, 0.001, "carry resets after whole conversion", failures)
```

Add main wiring assertions proving the run snapshot configures the system once and later saved-setting mutations do not alter it.

- [ ] **Step 2: Implement multiplier and carry**

Add fields and method:

```gdscript
var experience_multiplier := 1.0
var fractional_experience := 0.0

func configure_multiplier(percent: int) -> void:
	experience_multiplier = float(clampi(percent, 100, 1000)) / 100.0
	fractional_experience = 0.0
```

Replace the first line of `add_experience` with:

```gdscript
var scaled := float(maxi(amount, 0)) * experience_multiplier + fractional_experience
var whole_experience := floori(scaled)
fractional_experience = scaled - float(whole_experience)
experience += whole_experience
```

Keep the existing level-up loop unchanged.

- [ ] **Step 3: Configure at run start**

Immediately after creating `active_run_rules` in `Main.select_leader_class`, add:

```gdscript
experience_system.configure_multiplier(active_run_rules.experience_multiplier_percent())
```

- [ ] **Step 4: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/progression/experience_system.gd scripts/game/main.gd tests/unit/test_progression.gd tests/unit/test_main_wiring.gd
git commit -m "feat: apply next-run XP multiplier with carry"
```

### Task 5: Main Offer Sequence Wiring

**Files:**
- Modify: `scripts/game/main.gd:1-35,64-100,265-300`
- Modify: `tests/unit/test_main_wiring.gd`

**Interfaces:**
- Consumes: `LevelUpOfferState.seed_for(...)` and `LevelUpChoiceService.generate(..., offer_count, state)`.
- Produces: run-local `_level_up_offer_state: LevelUpOfferState` reset for each new run.

- [ ] **Step 1: Add failing run-seed/card-count tests**

Assert two main fixtures with different `game_run.run_seed` values produce different offer keys; a repeated call with an unchanged explicit state reproduces keys; Developer Mode count `7` produces seven choices while Player Simulation produces five.

- [ ] **Step 2: Wire offer state and deterministic seed**

Add:

```gdscript
var _level_up_offer_state := LevelUpOfferState.new()
```

Reset it after `active_run_rules` is created:

```gdscript
_level_up_offer_state = LevelUpOfferState.new()
```

Replace `_present_pending_level` seed generation with:

```gdscript
var offer_seed := _level_up_offer_state.seed_for(
	game_run.run_seed,
	experience_system.current_pending_level(),
	party_manager.members.size()
)
var choices := LevelUpChoiceService.generate(
	party_manager,
	catalog,
	offer_seed,
	active_run_rules.level_up_card_count(),
	_level_up_offer_state
)
_level_up_offer_state.offer_sequence += 1
get_node("HUD/LevelUpPanel").call(
	"show_choices",
	choices,
	party_manager,
	_invalid_choice_keys(choices),
	experience_system.pending_levels
)
```

The fifth argument anticipates Plan 04's pending-level indicator. Until Plan 04 lands, add an optional `pending_count: int = 1` parameter to `LevelUpPanel.show_choices` and store it without changing presentation.

- [ ] **Step 3: Run and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scripts/game/main.gd scripts/ui/level_up_panel.gd tests/unit/test_main_wiring.gd
git commit -m "feat: seed offers from run-owned sequence"
```

### Task 6: Developer Settings UI and Badge

**Files:**
- Modify: `scenes/ui/settings/additional_settings_page.tscn`
- Modify: `scripts/ui/settings/additional_settings_page.gd:1-135`
- Modify: `scripts/ui/developer_mode_badge.gd:12-22`
- Modify: `tests/unit/test_settings_screen.gd`
- Modify: `tests/unit/test_developer_mode_integration.gd`
- Modify: `tests/unit/test_responsive_ui.gd`

**Interfaces:**
- Adds scene paths `Layout/ExperienceMultiplier/Value`, `Layout/ExperienceMultiplier/Label`, `Layout/LevelUpCardCount/Value`, `Layout/LevelUpCardCount/Label`.
- Badge appends `XP N%` and `CARDS N` only for non-default active values.

- [ ] **Step 1: Add failing control/focus/badge tests**

Assert slider ranges `(100, 1000, 10)` and `(1, 8, 1)`, retained values while disabled, reset values `100/5`, write-back, focus order, and badge summary `DEV MODE | XP 500% | CARDS 7` when only those overrides differ.

- [ ] **Step 2: Add the two scene rows**

Use the existing `EnemyDensity` HBox pattern. The XP row uses title `Experience multiplier`, min `100`, max `1000`, step `10`, value `100`. The card row uses title `Level-up cards`, min `1`, max `8`, step `1`, value `5`.

- [ ] **Step 3: Bind, write, reset, disable, and focus both controls**

Add getters and label callbacks parallel to `_enemy_density()`. Include both sliders in `bind`, `write_to`, `reset_developer_options`, `_refresh_enabled_state`, `_refresh_value_labels`, and the enabled focus-order array.

The label bodies are:

```gdscript
func _on_experience_multiplier_changed(value: float) -> void:
	_experience_multiplier_label().text = "%d%%" % int(value)

func _on_level_up_card_count_changed(value: float) -> void:
	_level_up_card_count_label().text = "%d" % int(value)
```

- [ ] **Step 4: Extend badge summary**

After appending combat-policy summary parts:

```gdscript
if snapshot.experience_multiplier_percent() != 100:
	parts.append("XP %d%%" % snapshot.experience_multiplier_percent())
if snapshot.level_up_card_count() != 5:
	parts.append("CARDS %d" % snapshot.level_up_card_count())
```

- [ ] **Step 5: Run responsive/full tests and commit**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd
git add -- scenes/ui/settings/additional_settings_page.tscn scripts/ui/settings/additional_settings_page.gd scripts/ui/developer_mode_badge.gd tests/unit/test_settings_screen.gd tests/unit/test_developer_mode_integration.gd tests/unit/test_responsive_ui.gd
git commit -m "feat: expose progression developer controls"
```

### Task 7: Plan 02 Verification Gate

**Files:**
- Create: `docs/validation/evidence/2026-07-31-plan-02-progression.log`

- [ ] **Step 1: Verify**

```powershell
& $godot --headless --path $worktree --script res://tests/test_runner.gd 2>&1 | Tee-Object -FilePath "$worktree\docs\validation\evidence\2026-07-31-plan-02-progression.log"
& $godot --headless --path $worktree --editor --quit-after 2
git -C $worktree diff --check
```

Expected: all suites pass, settings resources parse, and the diff check is silent.

- [ ] **Step 2: Commit evidence**

```powershell
git add -- docs/validation/evidence/2026-07-31-plan-02-progression.log
git commit -m "test: record progression verification"
```
