# Resumable Run Recovery and Profile Deletion Design

Date: 2026-08-26

## Goal

Complete the unfinished profile lifecycle so a durable checked-out run can be resumed or abandoned after restarting the game, and profiles can be permanently deleted from Settings without leaving recovery artifacts or corrupting neighboring profiles.

Resume restarts the arena from the beginning. It preserves the original run identity, seed, selected leader class, player identity, leader member identity, and checked-out item state. It does not claim to restore the prior wave, timer, enemies, upgrades, ground drops, or other unsaved arena state.

## Current Problem

`ProfileState.resumable_run` already prevents a second checkout, but the main-menu view model ignores it. A player therefore sees **Begin Run**, attempts a new checkout, and receives the correct active-recovery rejection without any route to continue or abandon the saved run.

The existing same-process `_pending_checkout_recovery` in `Main` is only a retry mechanism for a checkout that just committed. It does not recover a run after restarting the game.

`ProfileManager` supports creation, discovery, activation, refresh, and mutation, but not permanent deletion. Settings > Profiles has no delete selection or confirmation flow.

## Player Experience

### Resume and Abandon

- Any valid nonempty `resumable_run` overrides the normal completed-profile **Begin Run** action.
- The primary main-menu action becomes **Resume Run** and opens a recovery confirmation surface.
- **Resume Run** restarts the arena from the beginning with the original durable run identity and checked-out items.
- **Abandon Run** requires a second explicit confirmation that states run-owned items will be permanently lost.
- Abandonment uses the existing strict forfeit contract. It clears only the matching recovery and never reconstructs run-only items in profile storage.
- Invalid recovery data cannot silently route to a new run. The recovery surface shows a safe failure and keeps confirmed abandonment available when the matching recovery can still be forfeited safely.

### Legacy Recovery

- Older recovery documents without `selected_leader_class_id` open **Choose Class to Recover Run**.
- The selected class is validated against the existing checked-out equipment and current catalog.
- A valid choice is atomically written into the existing recovery document before run-context creation.
- The class choice must not perform a second checkout or replace the existing run identity.
- A later restart resumes directly without asking for the class again.
- An incompatible or failed class choice leaves the recovery unchanged.

### Profile Deletion

- Settings > Profiles adds **Delete Selected Profile**.
- Deletion is permanent and requires confirmation naming the selected profile.
- The confirmation explicitly states that any resumable run and all run-owned items will also be discarded.
- Deletion is disabled while an arena run is actively running. A durable recovery by itself does not disable deletion.
- Healthy, backup-recovered, and damaged discovered profiles may be selected for deletion.
- Damaged profiles remain unavailable for activation but remain selectable for deletion.
- Deleting the active profile selects the most recently used remaining valid profile.
- Deleting the final profile returns the application to the existing no-profile/create-profile state.

## Recovery Architecture

### Durable Document

Advance the strict resumable-run schema and codec together to include `selected_leader_class_id`.

- New checkouts always persist a valid selected leader class.
- Older strict documents migrate with an empty legacy class marker while preserving all existing run and item data semantically.
- Encoding, decoding, migration, and checkout share one canonical contract.

### Run Recovery Service

Add a dedicated `RunRecoveryService` with a typed result boundary. It validates:

- active profile identity;
- strict recovery decoding and canonicalization;
- original run, seed, player, and leader member identity;
- selected or newly bound leader class;
- checked-out item ownership and equipment eligibility;
- current run rules required for context creation.

`MainMenuViewModel` owns the value-only **Resume Run** projection. `Main` owns the modal flow and asks the recovery service for a validated bootstrap before creating the normal runtime context. Durable resume never synthesizes `_pending_checkout_recovery` and never calls checkout again.

The existing `_pending_checkout_recovery` remains limited to same-process retry after a newly committed checkout.

## Profile Deletion Architecture

Add a typed `ProfileDeletionResult` and a narrow `ProfileDeletionService` used only through `ProfileManager`.

### Identity and Path Confinement

- Ordinary IDs must pass the existing profile-ID validator.
- Damaged-artifact deletion is accepted only for an ID discovered during the current manager bootstrap.
- Every deletion target must resolve to a confined basename under the exact configured profile root.
- Separators, traversal segments, drive prefixes, arbitrary paths, and undiscovered IDs fail before filesystem mutation.

### Exact Artifact Allowlist

For the exact selected profile primary path, deletion may remove only:

- the primary file;
- `.bak`;
- `.tmp`;
- `.bak.previous`;
- `.irreversible-primary.tmp`;
- `.irreversible-backup.tmp`;
- `.corrupt-<digits>`;
- `.bak.corrupt-<digits>`.

Timestamped corruption artifacts are discovered only by listing the exact profile root and matching the escaped selected-profile basename plus the numeric suffix. Neighboring profile files are never enumerated as deletion targets and must remain byte-for-byte unchanged.

### Manager State

After the irreversible boundary, `ProfileManager` removes the profile and status from memory, selects the most recently used remaining valid profile or clears the active ID, persists a rebuilt index, and emits the existing profile-change signals.

The deletion result distinguishes:

- a pre-commit failure where no deletion occurred;
- a committed deletion;
- a committed deletion with index-cleanup debt.

If all exact artifacts are verified absent but index persistence fails, the profile remains deleted in memory and must not reappear during the process.

## UI Boundaries

- The main menu projects recovery state but does not mutate it.
- `Main` coordinates recovery, class binding, abandonment, and run-context creation through public service boundaries.
- The Profiles settings page owns selection, confirmation text, cancel behavior, and focus restoration.
- `ProfileManager` owns deletion orchestration and post-commit profile selection.
- The deletion service owns irreversible filesystem work and confinement.
- Settings receives run-active state through an explicit callable or setter. The page must not inspect the scene tree or global `Main` state.

All new controls must support keyboard and controller focus. Cancel preserves the current selection and bytes. Successful deletion focuses the next selected profile, or the profile-name field when no profiles remain.

## Failure Handling

- Invalid recovery fails closed and never starts a fresh run implicitly.
- Legacy class validation or persistence failure leaves the recovery unchanged.
- Run-context creation failure preserves the durable recovery for retry.
- Abandonment failure preserves the recovery and its run-owned items.
- Deletion completes all identity, target, and confinement preflight checks before erasing anything.
- A filesystem failure before verified erasure is noncommitted and retains selection for retry.
- A verified erasure followed by index failure is committed with explicit cleanup debt.
- Canceling Resume, Abandon, or Delete performs no mutation.
- Safe player-facing errors and technical diagnostics remain separate.

## Testing and Acceptance

Development follows strict RED-GREEN-REFACTOR sequencing.

### Unit and Service Coverage

- current-format recovery and exact bootstrap preservation;
- legacy class binding and deterministic restart behavior;
- incompatible class and malformed recovery rejection;
- zero second checkouts during resume;
- strict matching abandonment and failure preservation;
- healthy primary-plus-backup deletion;
- backup-only recovered-profile deletion;
- damaged discovered-profile deletion;
- active-profile replacement and final-profile no-profile state;
- exact artifact allowlist and neighboring byte preservation;
- path-like and undiscovered-ID rejection;
- injected pre-commit removal failure;
- committed deletion with index-cleanup debt;
- main-menu Resume projection and invalid-recovery behavior;
- Profiles activation-versus-deletion eligibility;
- confirmation text, cancellation, focus, and active-run gating.

### Integration Coverage

Use unique isolated profile roots and production scenes to prove:

1. create a current-format recovery, restart `Main`, resume, and preserve run identity and items with zero second checkouts;
2. create a legacy recovery, restart, bind a class, restart again, and resume without another prompt;
3. reject an incompatible legacy class without changing durable recovery;
4. abandon only the matching recovery through the real confirmation flow;
5. delete inactive, active, final, recovered, and damaged profiles through real Settings controls;
6. disable deletion while `run_started` is true;
7. preserve controller focus and neighboring profile bytes.

Final verification requires fresh import, focused recovery/profile suites, real-scene integration runners, and the complete automated suite. Expected negative-path diagnostics are accepted only when the process exit code and explicit summary marker confirm the intended result; parser, loader, script, crash, ObjectDB, and resource-retention markers remain forbidden in strict gates.

## Out of Scope

- Restoring exact wave, timer, enemy, upgrade, ground-drop, or presentation state.
- Multiple simultaneous resumable runs for one profile.
- Cloud-save deletion or remote synchronization.
- Secure erase guarantees beyond permanent application-level artifact removal.
- Redesigning the broader Settings or main-menu visual language.
