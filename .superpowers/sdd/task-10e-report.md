# Task 10E Report — Equipment Attribute Requirements and Monotonic Modifier Policy

## Outcome

Task 10E is implemented on `feat/equipment-attribute-application` from starting commit `af9083b`.

The equipment boundary now owns one strict requirement schema for the six canonical core attributes. Requirement values must use `StringName` keys, be numeric, finite, and nonnegative. Equipment-authored core-attribute modifiers must be monotonic: zero is neutral for every supported operation, positive `FLAT`, `INCREASED`, and `MORE` values are allowed, while every negative value and positive `REDUCED`/`LESS` value is rejected.

The activation resolver validates every equipped base and roll before entering its fixed point, including disabled items, rejects nonfinite or negative raw requirement attributes, and verifies that no successive activation pass decreases a requirement attribute. This closes the signed non-equipment-factor counterexample that an operation-only policy cannot exclude.

Malformed canonical data fails closed with stable item/base/affix/stat/operation/value context. The eligibility, activation, modifier projection, item presentation, profile storage projection, and developer sandbox paths do not coerce malformed requirements or bind presentation errors as normal item data. Profile item details are accumulated locally and published only after every item projects successfully.

## Canonical contracts

- `EquipmentBaseDefinition.REQUIREMENT_ATTRIBUTE_IDS` aliases the existing canonical six core IDs: Strength, Dexterity, Constitution, Intelligence, Wisdom, and Charisma.
- `EquipmentBaseDefinition.validate_attribute_requirements()` sorts keys for deterministic diagnostics and rejects string keys, unknown attributes, nonnumeric values, NaN/infinity, and negative values.
- `EquipmentBaseDefinition.monotonic_core_modifier_error()` is the shared authoring/runtime policy.
- `ItemAffixDefinition.validate()` audits the minimum and maximum of every authored core-attribute tier range.
- `EquipmentModifierProjector.project()` applies the same policy to actual immutable rolls, with full instance and affix context.
- `EquipmentActivationResolver.resolve()` preflights all equipped instances and rejects any successive raw core-attribute decrease.

## Live catalog audit

The audit runs through `test_game_catalog.gd` and covers the complete current catalogs:

- 99 equipment bases validate against the strict requirement schema.
- All 99 bases still issue a common immutable item, and every issued item revalidates.
- 7 live affix definitions validate against the monotonic modifier policy.
- Current live requirement dictionaries are empty; no canonical content rewrite was required.
- Current core-attribute affixes are positive flat Constitution, Dexterity, or Wisdom grants and conform without normalization.
- Malformed requirement fixtures and policy fixtures use owned definition copies. A same-process affected batch runs presentation rejection before the live audit, proving the fixtures do not mutate `GameCatalog`.

No live-data conflict required escalation.

## TDD and review history

Accepted RED evidence:

- Initial four-suite requirement/modifier/activation/assignment gate: `TEST_SUMMARY: FAIL (24 failures)`, exit `1`. Failures were the missing strict schema and monotonic policy behavior.
- Disabled corrupt-roll preflight regression: activation suite failed before all-equipped preflight was added.
- Signed-factor fixed-point regression: activation suite `TEST_SUMMARY: FAIL (3 failures)`, exit `1`, before successive-pass monotonic comparison.
- Profile presentation caller regression: `TEST_SUMMARY: FAIL (3 failures)`, exit `1`, before the caller rejected the projector's `{error}` result.
- Valid-before-invalid profile atomicity regression: `TEST_SUMMARY: FAIL (1 failures)`, exit `1`, showing the earlier valid record was partially published before local accumulation was added.

Rejected/non-evidence runs:

- One early combined RED attempt contained a typed-array fixture error and was discarded.
- One post-review mixed batch and one complete-suite attempt exposed that `Resource.duplicate(true)` had shared an external equipment subresource. The malformed presentation test had mutated the live `windrunner_band` definition. Those runs were discarded; the fixture now constructs a catalog from individually duplicated definitions and asserts canonical immutability.

Independent review found and drove fixes for:

1. A signed non-equipment factor that could make a positive equipment modifier reduce a resolved requirement attribute. Fixed with nonnegative raw values plus successive-pass monotonic comparison.
2. Coercive item presentation of malformed requirements. Fixed with fail-closed schema validation at projection entry.
3. A test fixture that mutated the canonical external equipment resource. Fixed with individually owned definition copies and canonical byte checks.
4. Profile and developer-sandbox callers treating a presentation error dictionary as valid detail. Fixed by propagating/rejecting the error and binding an empty detail document.
5. Profile projection retaining earlier valid records when a later sorted record failed presentation. Fixed by accumulating locally and publishing only after the full loop succeeds.

Follow-up parent review found two additional Important blockers:

1. Developer sandbox refresh published registry/container/projection/comparison fields and slot bindings incrementally, while move transactions persisted before presentation validation. The valid-before-invalid end-to-end regression failed 15 assertions across OPEN, transfer, and first-empty move. Sandbox state actions now accept a candidate validator before commit/persistence, and `_refresh_projection()` stages the registry, inventory, stash, serialized document, comparison projection, and all 105 slot details before publishing or binding anything. The regression asserts exact slot bindings, in-memory state bytes, and every persisted artifact byte remain unchanged.
2. The stats-ledger test could abort on an exact missing-row lookup after leaving its primary-action fixture nulled and ignoring a coordinated source-application result. The runner then reported a false pass because it trusted only the suite's returned array. The fixture now restores its primary action, asserts source application, guards the data-driven row lookup with an explicit failure, and reaches equipment attribution and cleanup. Both test runners now install a mutex-protected Godot `Logger` and convert every `ERROR_TYPE_SCRIPT` event into a test failure.

Deliberate runner proof:

```text
before: TEST_SUMMARY: PASS (0 failures), exit=0, followed by deliberate SCRIPT ERROR
after:  TEST_SUMMARY: FAIL (1 failures), exit=1, captured file/line/reason
```

The probe lives under `tests/support`, so normal unit-suite discovery does not include it.

## Fresh verification

Godot: `4.7.1.stable.official.a13da4feb`.

Focused presentation caller batch after the final caller fixes:

```text
TEST_SUMMARY: PASS (0 failures)
exit=0
```

Same-process 18-suite final affected gate, ordered so malformed presentation fixtures run before the live catalog audit and including sandbox state/UI plus ledger page/provider coverage:

```text
TEST_SUMMARY: PASS (0 failures)
exit=0
```

The gate covered modifier projection, activation, assignment, item presentation, profile storage, developer sandbox state/UI, stats ledger page/provider, full game catalog, generation definitions, equipment contracts/transitions, profile assignment, non-equipment refresh, member stat resolution, derived attributes, and resolved-stat comparisons. It completed with no captured script errors.

24-member integration scenario:

```text
EQUIPMENT_ATTRIBUTE_APPLICATION_SUMMARY: PASS members=24 untouched=23 items=2
exit=0
```

Fresh complete suite:

```text
TEST_SUMMARY: PASS (165 suites)
exit=0
captured SCRIPT ERROR count=0
```

`git diff --check` passed before the report/commit cycle.

## Files changed

Production:

- `scripts/dev/developer_item_sandbox_state.gd`
- `scripts/equipment/equipment_activation_resolver.gd`
- `scripts/equipment/equipment_base_definition.gd`
- `scripts/equipment/equipment_eligibility.gd`
- `scripts/equipment/equipment_modifier_projector.gd`
- `scripts/items/item_affix_definition.gd`
- `scripts/ui/developer_item_sandbox.gd`
- `scripts/ui/storage/item_presentation_projector.gd`
- `scripts/ui/storage/profile_storage_projection.gd`

Tests:

- `tests/focused_test_runner.gd`
- `tests/test_runner.gd`
- `tests/support/script_error_capture_probe.gd`
- `tests/support/test_script_error_capture.gd`
- `tests/unit/test_developer_item_sandbox.gd`
- `tests/unit/test_equipment_activation_resolver.gd`
- `tests/unit/test_equipment_assignment_service.gd`
- `tests/unit/test_equipment_modifier_projector.gd`
- `tests/unit/test_game_catalog.gd`
- `tests/unit/test_item_presentation_projector.gd`
- `tests/unit/test_profile_storage_projection.gd`
- `tests/unit/test_stats_ledger_page.gd`

Report:

- `.superpowers/sdd/task-10e-report.md`

## Hygiene and concerns

- No canonical `.tres` data, generator policy, swap planner, or storage comparison calculation was rewritten.
- Pre-existing untracked Godot `.gd.uid` sidecars remain in the worktree and are excluded from the Task 10E commit.
- The complete suite retains established intentional negative-path errors and storage-cleanup warnings. The hardened runner distinguishes those ordinary logged errors from runtime script errors; the authoritative fresh result is exit `0`, `PASS (165 suites)`, and zero captured `SCRIPT ERROR` events.
- The fixed-point contract deliberately fails closed if future non-equipment math causes adding active equipment to lower any requirement attribute, even when the final value remains nonnegative. Such a future design needs an explicit solver/policy redesign rather than a silent exception.
