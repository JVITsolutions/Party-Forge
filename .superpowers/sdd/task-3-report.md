# Task 3 Implementation Report

Status: DONE

## Scope

- Created `tools/build_modular_equipment_backup.gd`.
- Created `tests/unit/test_modular_equipment_backup_builder.gd`.
- No production backup was invoked.
- No authoritative main checkout, legacy asset, or `scenes/equipment/test_equipment/` file was read for test copying, modified, deleted, or staged.
- Tests used a two-file explicit inventory under a unique disposable Godot user-data directory and removed only explicitly known files/directories, leaf-first, without recursive deletion.

## Implementation

- The `SceneTree` entry point accepts required named `--source-root`, `--output`, `--source-commit`, and `--source-branch` arguments in `--name value` or `--name=value` form.
- CLI parsing and Git-status collection are separate from the `BackupService` copy/hash API, so tests call the service directly without subprocesses.
- Request validation requires an absolute existing source root with `project.godot` directly beneath it, an absolute absent-or-empty output outside the source root, a nonempty branch, an exact 40-character hexadecimal commit, and a nonempty normalized unique inventory.
- The service sorts the explicit inventory, rejects traversal/reserved output names, creates only required external parents, copies bytes through read/write buffers, verifies destination bytes, and hashes the bytes actually copied.
- The deterministic final `manifest.json` records schema/state, source root, commit, branch, full worktree status, exact expected/file counts, total bytes, and sorted relative path/size/SHA-256 rows.
- The final manifest is written only after every inventory copy verifies. Copy failure leaves copied bytes in place, omits the final manifest, and writes a bounded `backup.failure.json` plus `partial-manifest.json` containing completed rows and explicit owned paths.
- The production implementation contains no delete, recursive cleanup, rename, source write, or target-overwrite operation.

## TDD evidence

The first attempted RED run exposed a test-only type-inference parse error. That test harness issue was corrected before accepting any RED result; it was not counted as RED.

Accepted RED command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_builder.gd
```

Accepted RED result: exit code `1`; `TEST_SUMMARY: FAIL (1 failures)`; genuine assertion:

```text
backup builder implementation exists: expected res://tools/build_modular_equipment_backup.gd
```

No production implementation file existed during accepted RED.

Initial GREEN command: same focused command.

Initial GREEN result: exit code `0`; `TEST_SUMMARY: PASS (0 failures)`.

## Verification

Task 2 inventory plus Task 3 builder focused command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 180 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_inventory.gd res://tests/unit/test_modular_equipment_backup_builder.gd
```

Result before staging: exit code `0`; `TEST_SUMMARY: PASS (0 failures)`.

Full suite command:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 600 --script res://tests/test_runner.gd
```

Result: exit code `0`; `TEST_SUMMARY: PASS (205 suites)`. The emitted error/warning diagnostics were established intentional negative-path coverage; no `TEST_FAILURE` summary occurred.

Final staged focused run: exit code `0`; `TEST_SUMMARY: PASS (0 failures)`.

`git diff --cached --check`: exit code `0`, no output.

## Files changed and commit

- `tools/build_modular_equipment_backup.gd`
- `tests/unit/test_modular_equipment_backup_builder.gd`

Commit:

`866d6d57b32b88ff61c95a2297a4b277516213ce` - `feat: add bounded modular equipment backup builder`

Only the two task files were included in the commit.

## Self-review and concerns

- Coverage exercises named argument parsing, missing arguments, relative output, output inside the source, existing non-empty output, malformed commit, wrong project root, parent creation, byte preservation, source immutability, metadata/hashes, exact inventory confinement, deterministic manifest bytes, failure preservation, bounded failure marker, partial ownership, sibling preservation, and traversal rejection.
- The service has no dependency on the production 534-file inventory during tests.
- The CLI itself was deliberately not spawned in tests, as required; its parser and pure service are exercised separately, and loading the tool covers the complete script parser.
- Concerns: none.

## Safety-review hardening follow-up

Status: DONE

The review findings were addressed only in `tools/build_modular_equipment_backup.gd` and `tests/unit/test_modular_equipment_backup_builder.gd`. No production backup, authoritative-checkout write, legacy-asset mutation, recursive deletion, or production-inventory copy was performed.

### Additional accepted RED evidence

All focused RED/GREEN cycles used:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_builder.gd
```

- Review RED 1: exit `1`, `TEST_SUMMARY: FAIL (2 failures)` for the absent injected race-safe filesystem API and absent actual-Git metadata validation API.
- Review RED 2: exit `1`, `TEST_SUMMARY: FAIL (3 failures)` for missing exact output-root containment configuration and adversarial metacharacter-path copying.
- Review RED 3: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` for the missing inspectable native-helper encoding boundary.
- Review RED 4: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` for the absent stdin-pipe boundary needed to keep content writing inside the same exclusive native create operation.
- Review RED 5: exit `1`, `TEST_SUMMARY: FAIL (2 failures)` for missing verified failure artifacts and missing `.` ownership when output-root creation failed after mutation.

Harness-only parse/type-inference failures encountered while authoring RED 5 were corrected and were not accepted as behavioral RED evidence.

### Hardened implementation

- The filesystem adapter is injected into the pure service. Production path probes fail closed on any symlink, junction, or other reparse component in the source, output's nearest existing parent, and every inventory path.
- Production mutations use a bounded encoded PowerShell/.NET adapter. User paths are UTF-8/base64 encoded inside a UTF-16 `-EncodedCommand`; no path or content is interpolated into shell source.
- Every directory uses atomic `CreateDirectoryW`; every file uses `FileMode.CreateNew`; content is streamed into that still-open exclusive file handle, flushed, length-checked, and SHA-256 checked before close. Non-blocking pipe writes are bounded and retried under back-pressure.
- Every created directory/file is registered immediately, including partial destination files and the earliest partially created output. Post-mutation failures attempt and read-back verify both the bounded failure marker and partial ownership manifest, and return preservation status plus owned paths.
- `manifest.json` is never opened for writing. The service exclusively writes and verifies `.manifest.pending.json`, then publishes it with atomic no-replace `File.Move`; publish failure leaves no success manifest.
- Source and destination reads must report an accepted status, exact expected length, exact bytes read/position, a valid lowercase SHA-256, local hash agreement, and source/destination hash plus byte equality before a manifest row completes.
- CLI startup probes actual Git HEAD, symbolic branch, and full porcelain status and rejects any caller commit/branch mismatch before inventory construction or output creation.

### Final verification

- Focused Task 3: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Focused Tasks 2+3: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Disposable native helper stress: exit `0`; exact `100000` bytes on an output path containing spaces, `&`, `$`, brackets, and `;`; exclusive create and atomic publish both succeeded. The temporary runner and exact disposable root were explicitly removed and verified absent.
- Full suite: exit `0`, `TEST_SUMMARY: PASS (205 suites)`.
- `git diff --check`: exit `0`, no output.

### Concerns

- The native helper is Windows-specific by design for this Windows backup workflow and fails closed if PowerShell or required Win32/.NET primitives are unavailable.
- No production backup was invoked; native behavior was limited to the explicit disposable 100 KB stress artifact.

Hardening commit: `7d571b5` - `fix: harden modular equipment backup safety` (only the two Task 3 code/test files).

## Second safety-review handle hardening

Status: DONE

This follow-up remained confined to `tools/build_modular_equipment_backup.gd` and `tests/unit/test_modular_equipment_backup_builder.gd`. It did not invoke a production backup, write to the authoritative checkout, copy the production inventory, mutate legacy assets, or recursively delete any path.

### Accepted RED evidence

The focused Task 3 command was used for each RED/GREEN cycle:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_builder.gd
```

- Handle-contract RED: exit `1`, `TEST_SUMMARY: FAIL (7 failures)` for absent canonical identity/source configuration, one-operation guarded copy, supervision contract, required Git top-level, output identity-alias rejection, and Git top-level mismatch rejection.
- Native API RED: exit `1`, `TEST_SUMMARY: FAIL (2 failures)` for absent bounded supervision injection and 8.3 short-path inspection.
- Native boundary RED: exit `1`, `TEST_SUMMARY: FAIL (6 failures)` for UNC fail-closed, SUBST identity/containment, bounded timeout, confirmed termination, and ownership recovery.
- Initial handle-helper RED: exit `1`, `TEST_SUMMARY: FAIL (14 failures)` for a reversed missing-path probe mode that blocked output setup and all dependent native boundaries.
- Service-routing RED: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` because the service made zero calls to the required one-operation guarded copy API instead of one call per inventory file.
- Bounded Git supervisor RED: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` for the missing shared bounded subprocess API.
- Abnormal-exit contract RED: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` for missing abnormal-exit ownership reconciliation.
- Large-status supervision RED: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` because an undrained 100 KB subprocess output deadlocked until timeout.

GDScript parse/type errors while assembling the helper and a disposable-cleanup ordering failure were harness defects, not accepted behavioral RED evidence.

### Implemented safety boundaries

- A bounded encoded PowerShell/.NET helper opens every existing local path component with `FILE_FLAG_OPEN_REPARSE_POINT`, rejects reparse components and UNC paths, derives canonical volume/file identity with `GetFileInformationByHandle`, and retains component handles without `FILE_SHARE_DELETE` for each complete probe, copy, create, directory-create, and publication operation.
- The configured source identity must equal the actual Git top-level identity. Each source copy chain must contain that source anchor, and each output mutation chain must contain the separately captured nearest-existing-output-ancestor identity. SUBST and supported 8.3 aliases therefore compare by object identity rather than spelling.
- Copy uses one helper operation with held source and destination-parent handles, source identity revalidation, destination `CREATE_NEW`, immediate ownership output, full source and destination lengths/positions, valid SHA-256 values, and equality before a manifest row is completed.
- Every file uses Win32 `CREATE_NEW`; every directory uses `CreateDirectoryW`; no collision truncates or replaces bytes. Artifact bytes are flushed and reread on their still-open exclusive handle. The pending manifest is published last with atomic same-volume `MoveFileExW` and no replace flag.
- Every created object is announced and flushed before injected delay or subsequent work. Bounded supervision confirms helper termination, then reconciles announced ownership against the object's canonical identity on timeout or other abnormal exit.
- Git HEAD, symbolic branch, full porcelain status, and top-level probes share the bounded process supervisor. The supervisor continuously drains up to 16 MiB, so a 100 KB status does not deadlock; larger output fails closed.
- The service remains independently injectable/testable. CLI parsing, actual Git probing, source identity verification, inventory construction, and output mutation remain separate stages, with all Git/caller verification occurring before output creation.

### Native disposable coverage

- UNC/local aliases fail closed.
- SUBST source aliases resolve to the same identity and cannot be configured as output inside the source.
- 8.3 aliases compare by identity when supported; disabled aliases report explicit unavailability.
- Existing-file and final-manifest collisions preserve sentinel and pending bytes.
- A post-create timeout is killed, termination is confirmed, and the created directory is recovered by identity as owned.
- A guarded native source copy preserves exact bytes.
- Native `CREATE_NEW` streams and verifies exactly `102400` bytes.
- The native service completes copy, verified pending artifact, and manifest-last publication end to end in a disposable directory.

### Verification

- Focused Task 3: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Focused Tasks 2+3: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Full suite: exit `0`, `TEST_SUMMARY: PASS (205 suites)`.
- `git diff --check`: exit `0`, no output.

### Concerns

- The native contract intentionally supports local Windows paths only and fails closed for UNC paths, unavailable handle primitives, helper launch failure, helper timeout, unconfirmed termination, output above the bounded capture limit, or identity mismatch.
- No production backup was invoked. All native mutation tests used a tiny explicit disposable inventory and explicitly tracked files/directories for non-recursive cleanup.

Second safety-review fix commit: `f2546c8` - `fix: anchor backup safety to native handles` (only the two Task 3 code/test files).

## Trusted-local-workstation simplification

Status: DONE

The user approved trusted-local-workstation option A, recorded in design/plan commit `1490fc2a8c6da8ddfae5756c4f63e8b81cbd9aef`. This supersedes the hostile-filesystem assumptions in the two earlier safety-review sections while preserving their historical RED/GREEN evidence. The implementation remains confined to `tools/build_modular_equipment_backup.gd` and `tests/unit/test_modular_equipment_backup_builder.gd`; no production backup, authoritative-checkout write, production-inventory copy, legacy-asset mutation, or recursive deletion occurred.

### Accepted RED evidence

The focused Task 3 command was used for each cycle:

```powershell
& 'F:\Projects(root)\Game dev\godot\Godot_v4.7.1-stable_mono_win64\Godot_v4.7.1-stable_mono_win64_console.exe' --headless --path . --quit-after 120 --script res://tests/focused_test_runner.gd -- res://tests/unit/test_modular_equipment_backup_builder.gd
```

- Local-adapter API RED: exit `1`, `TEST_SUMMARY: FAIL (1 failures)` for the missing trusted local filesystem constructor.
- Scope-contract RED: exit `1`, `TEST_SUMMARY: FAIL (8 failures)` for retained PowerShell/hostile-process machinery, three unsafe source path forms, three unsafe output path forms, and the required Git top-level mismatch contract.
- Pre-probe/top-level RED: exit `1`, `TEST_SUMMARY: FAIL (2 failures)` for missing public local-path validation and direct Git top-level mismatch validation.

These were behavioral assertion failures. The implementation was changed only after each RED was observed, and each cycle returned to focused `PASS (0 failures)` before refactoring continued.

### Simplified implementation

- Replaced the embedded PowerShell/.NET/Win32 helper, handle identity model, process supervision, alias probing, and hostile termination reconciliation with a small ordinary-GDScript `LocalFilesystem` adapter appropriate to the approved trusted workstation boundary.
- The CLI validates explicit local absolute source/output paths and rejects UNC/device forms before any filesystem or Git probe. It then captures actual Git HEAD, symbolic branch, full porcelain status, and top-level, rejecting caller commit/branch or top-level mismatch before inventory construction or output creation.
- The pure service remains separately injectable and validates the same path and metadata contract. Output must be lexically outside the source and absent or empty; inventory entries must be exact normalized relative paths and cannot name builder-reserved artifacts.
- Local operations never delete or recursively clean. Existing files are rejected before write, copied files are reread, and source/destination status, full lengths, positions, lowercase SHA-256 values, hashes, and bytes must agree before a manifest row completes.
- The deterministic success manifest is written to `.manifest.pending.json`, read-back verified, and renamed to `manifest.json` only after all copies complete. Ordinary copy/write/publish failures preserve a bounded failure marker and partial ownership manifest when those artifacts can be created and verified.

### Complexity reduction

Measured against `f2546c8`:

- Production builder: `867` to `625` total lines, `752` to `536` nonblank lines, and `51` to `40` functions.
- Task 3 tests: `758` to `571` total lines, `651` to `489` nonblank lines, and `40` to `34` functions.
- Combined: `1625` to `1196` total lines (`429` fewer, `26.4%` reduction), `1403` to `1025` nonblank lines (`378` fewer, `26.9%` reduction), and `91` to `74` functions (`17` fewer, `18.7%` reduction).

### Verification

- Focused Task 3: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Focused Tasks 2+3: exit `0`, `TEST_SUMMARY: PASS (0 failures)`.
- Full suite: exit `0`, `TEST_SUMMARY: PASS (205 suites)`.
- `git diff --check`: exit `0`, no output.

### Concerns

- By approved design, ordinary GDScript check-then-open/check-then-rename operations are not a security boundary against a malicious concurrent local process. That adversarial race model is explicitly out of scope for this trusted workstation transaction.
- The Git probes are ordinary blocking commands. Nonzero exits fail closed; hostile process termination and maliciously hung Git are outside the approved scope.
- Local drive-letter paths are supported; UNC and device paths intentionally fail closed.

Trusted-local-workstation simplification commit: `05486bc` - `feat: add bounded modular equipment backup builder` (only the two Task 3 code/test files).

- No open Task 3 functional concern is known.
- The retained expansion migration still fails its later class validation on existing starter-loadout capability/tag mismatches. This did not prevent its attack rows from being emitted and verified, and is outside the reviewed tag-preservation defect.
- The focused runner can return exit `0` after a suite-load parse failure, so accepted evidence requires both the expected PASS marker and absence of `TEST_FAILURE`/parse/load failures.
- The report is a pre-existing tracked coordination artifact and is included in the scoped Task 3 commit.

# Multi-Crit Task 3 addendum: bounded authoritative roll preparation

Date: 2026-08-23

Status: implementation and requested verification complete; scoped commit is this report's commit (`feat: prepare bounded multi-crit rolls`).

## Scope and implementation

- Worktree: `F:\Projects(root)\Game dev\Projects\party-forge\.worktrees\playtest-recovery-loot-ui`
- Branch: `feat/playtest-recovery-loot-ui`
- Starting head: `27be0ef848242eb8d547e0e57327d0e07a0a1875`
- Added `MultiCritRoll` as immutable preparation metadata with copied ordered flags, whole-percentage normalization, uncapped requested/guaranteed counts, a 10,000 processed-instance ceiling, fractional-roll evidence, and explicit truncation evidence.
- Below 100%, the roll records exactly one normal-or-critical flag. At or above 100%, it records bounded guaranteed critical flags plus a successful remainder only when a processing slot remains.
- `DamagePacket.multi_crit_roll` is authoritative and defensively copied. Compatibility accessors `critical` and `crit_draw` read the authoritative roll's first outcome and fractional draw.
- `DamageResolver.prepare()` creates the roll once before component sampling, then prepares one component set exactly once. The existing compatibility `post_crit` amount uses the first/resulting flag; later tasks own iteration and independent defended instance resolution.
- `PreparedDamageComponent` required no Task 3 change because its existing `typed_scaled` field already preserves the once-prepared normal base needed by later per-instance critical multiplication.
- No additional projectile, repeated weapon sample, defender dodge/block loop, proc dispatch, presentation staggering, death/overkill processing, or other Task 4+ behavior was added.

## Strict TDD evidence

The pre-change relevant baseline batch (`test_damage_resolver.gd`, `test_action_damage_component_projection.gd`, `test_combat_rng.gd`, and `test_typed_combat_final_fixes.gd`) exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

Tests were then added before production changes. The exact required focused RED command exited `1` with:

```text
TEST_SUMMARY: FAIL (8 failures)
```

Accepted RED failures were exactly:

- missing `multi_crit_roll.gd`;
- missing authoritative packet metadata in the resolver and weapon-projection fixtures;
- old at-or-above-100% behavior did not consume the processable fractional draw;
- shifted weapon range values were `10.4` and `5.0` instead of `12.5` and `7.0`;
- shifted compatibility post-critical values were `20.8` and `10.0` instead of `25.0` and `14.0`;
- total draw count was `2` instead of `3`.

Two intermediate GREEN attempts were rejected as evidence: one process exited `0` without a `TEST_SUMMARY` after a new-class self-reference compile failure, and one proper test run still exposed floating boundary behavior at the exact `0.05` draw. The implementation was minimally corrected to normalize through integer percentage points so equality at the prescribed boundary fails deterministically.

The exact required focused command then exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

The final focused run after self-review type tightening also exited `0` with the same PASS marker and no parse/load/test failure.

## Boundary and safety coverage

- `0%`: no draw, one normal flag.
- `5%`: `0.04` critical, `0.05` normal, exactly one draw.
- `99%`: `0.98` critical, `0.99` normal, exactly one draw.
- `100%`: no draw, one guaranteed critical flag.
- `105%`: `0.04` produces two critical flags; `0.05` produces one guaranteed critical flag; exactly one fractional draw.
- `1150%`: `0.49` produces twelve critical flags; `0.50` produces eleven; exactly one fractional draw.
- `10000.05` reports `10001` requested potential instances and `10000` processed/guaranteed flags, marks truncation, allocates exactly 10,000 flags, preserves the fractional chance, and consumes no fractional draw because no processable slot remains.
- Direct metadata mutation attempts and mutation/clearing of an exposed flag array leave the authoritative values and ordered flags unchanged.
- The runtime `105%` weapon fixture proves end-to-end uncapped resolver behavior, one remainder draw followed by one draw per sorted non-fixed component, and one base component set rather than one set per critical flag.

## Compatibility and repository verification

The post-change legacy compatibility batch (`test_combat_rng.gd` and `test_typed_combat_final_fixes.gd`) exited `0` with:

```text
TEST_SUMMARY: PASS (0 failures)
```

The known-stale compatibility batch exited `1` with exactly the five failures declared in the Task 3 brief and no additions:

- `test_attack_execution.gd`: three stale health/RNG expectations;
- `test_action_combat_estimate_service.gd`: two stale average-hit/DPS expectations.

The repository-wide suite also exited `1` with exactly:

```text
TEST_SUMMARY: FAIL (5 failures)
```

Those are the same five pre-existing baseline-migration expectations. No additional suite failed.

`git diff --check` passed before staging. A staged-scope diff check and final focused/compatibility reruns are recorded immediately before commit.

## Self-review and concerns

- Review confirmed the processing ceiling bounds allocation before `resize()` and that an unprocessable remainder consumes no RNG.
- Review confirmed `requested_instances` represents the uncapped guaranteed count plus a potential fractional slot, while `processed_instances` is the bounded ordered flag count after the fractional result.
- Review confirmed all public metadata setters ignore writes, flag getters return copies, and packet construction/getters copy the roll so caller-held objects cannot mutate packet authority.
- Godot cannot resolve a brand-new script's own `class_name` identifier during this worktree's first cold import. Its static factory/copy return annotations therefore use `RefCounted`; packet/resolver fields, accessors, parameters, and locals use the concrete preloaded `MultiCritRoll` script type. This preserves cold-import reliability without weakening external Task 3 contracts.
- The focused suite continues to print existing intentional negative-path diagnostics and the existing ObjectDB/resource exit markers; accepted PASS evidence requires the explicit summary and absence of parse/load/test failures.
- The five declared stale full-suite expectations remain for Tasks 6 and 7 as planned. They were not rewritten outside Task 3's contract.
- The user-owned untracked QA evidence paths remain untouched and unstaged. `.superpowers/sdd/progress.md` was not modified or staged, and the main Godot editor/process was not touched.

## Post-review correction: finite-range safety and explicit invalid input

Independent review found that the original integer-percentage normalization multiplied every finite chance by `100.0` before applying the 10,000-instance bound. A finite value such as `1.0e100` therefore reached `roundi()` outside its representable integer range, wrapped to a negative value, and manufactured one normal flag. The same public factory also converted `NAN`/`INF` to valid-looking zero-chance metadata.

### Strict correction RED evidence

Regression tests were saved before changing production. The exact Task 3 focused command exited `1` with:

```text
TEST_SUMMARY: FAIL (13 failures)
```

The accepted failures showed `1.0e100` becoming `-92233720368547760.0`, requested/processed counts of `1`, no truncation, one normal flag, absent overflow diagnostics, and absent structured rejection metadata for `NAN`, positive infinity, negative infinity, and resolver preparation.

After the first minimal correction passed, the requested safe-conversion transition probe exposed a second legitimate RED at the old `9.0e16` normalization boundary:

```text
TEST_FAILURE: tests/unit/test_multi_crit_roll.gd :: below safe-snapping transition preserves requested count: expected 89999999999999984, got 89999999999999985
TEST_SUMMARY: FAIL (1 failures)
```

That failure proved the still-large multiply/divide path could invent a fractional requested slot even without integer wrap. It was not accepted as GREEN.

### Corrected model and boundary behavior

- Finite chances stay nonnegative and authoritative. Percentage-point normalization is restricted to `90071992547409.0`, a conservative boundary whose `chance * 100.0` product remains within binary64's exact-integer range. Larger finite values bypass unsafe multiplication and preserve their raw finite value.
- Normal representable inputs retain the exact integer-percentage boundary behavior. Direct cases cover `0.0111 -> 0.01`, values immediately below/above the half-point rounding boundary, and prescribed RNG draws at the snapped threshold.
- Bounded processing is selected from the finite floating guaranteed count before integer conversion. No path allocates more than 10,000 flags.
- `requested_instances` and `guaranteed_instances` saturate at `INT64_MAX`. Read-only `requested_count_overflow` distinguishes saturation from an exact representable count, is retained by `copy()`, and also makes truncation explicit.
- The requested-count addition uses a prechecked fractional slot (`guaranteed <= INT64_MAX - fractional_slot`) so the addition itself cannot wrap. Binary64 has no fractional resolution immediately below `INT64_MAX`, but the defensive arithmetic remains correct if the representation or source type changes.
- Public `MultiCritRoll.create()` returns immutable, non-null structured rejection metadata for `NAN` and both infinities: `valid == false`, a stable finite-chance diagnostic, zero counts/flags, and zero RNG consumption. Copies preserve the rejection. `DamageResolver.prepare()` converts it to its established invalid packet form, avoiding any production null-dereference risk.
- Boundary coverage includes the old `9.0e16` conversion area and adjacent binary64 values, below/at/above the new exact-product transition, the last binary64 step below the signed-64 limit, the signed-64 limit itself, and `1.0e100`. All full-ceiling cases produce exactly 10,000 true flags and consume no remainder draw.

### Final correction verification

The exact required focused batch exited `0` after the final transition and immutability coverage with:

```text
TEST_SUMMARY: PASS (0 failures)
```

The standalone pathological multi-crit batch and the legacy `test_combat_rng.gd` plus `test_typed_combat_final_fixes.gd` compatibility batch each exited `0` with the same PASS marker.

The declared stale compatibility batch exited `1` with exactly its known five failures and no additions. The final repository-wide suite also exited `1` with:

```text
TEST_SUMMARY: FAIL (5 failures)
```

Those remain the three planned `test_attack_execution.gd` expectations and two planned `test_action_combat_estimate_service.gd` expectations already documented above. No cold import was required because the correction added no new script or public type reference. Final focused rerun, staged-scope review, `git diff --check`, and commit evidence follow this report update.
