# Body-Specific Production Rig Mapping Amendment

**Status:** Approved design amendment; implementation is not authorized by this document

**Date:** 2026-09-01

**Branch at authoring:** `feat/class-preview-character-model-replacement`

**Parent implementation checkpoint:** `3529ac849b37306615cd5e3dec5aa287aac08afa`

## Purpose

This amendment replaces the earlier assumption that the masculine and feminine production bodies could share one `pf_humanoid_v1_mixamo52` mapping resource. Direct Godot inspection proved that the two candidates have the same 52-bone names, indices, hierarchy, and Party Forge semantic mapping, but different native rest transforms, inverse-bind poses, source hashes, and rest signatures.

Party Forge will preserve those body-specific native poses. It will use two mapping resources that share the canonical semantic rig ID and 19-role bone-name mapping while retaining distinct source identities. The imported GLBs remain immutable.

This document amends singular mapping-resource references in `docs/superpowers/plans/2026-08-31-production-character-equipment-replacement.md`. The plan itself is not modified in this documentation gate. A separately approved implementation plan must reconcile those references before code or resource work begins.

## Authoritative Evidence and Immutable Inputs

The bounded inspection used Godot `4.7.1.stable.mono.official.a13da4feb` with direct external `GLTFDocument.append_from_file` parsing. The final evidence run exited `0`, emitted exactly one `RIG_INSPECTION_OK` marker, had empty stderr, and passed all 28 evidence checks.

Evidence directory:

`C:\Users\Jacob\AppData\Local\Temp\pf-rig-inspection-20260901T034123Z-7f9b59d1\evidence-0003`

Primary evidence files:

- `rig-inspection.json`: complete node, skeleton, bone, rest, skin, bind, mesh, and mapping data.
- `validated-findings.json`: derived contract findings and exact transform differences.
- `validated-findings.md`: human-readable summary and 19-role table.
- `containment-report.json`: source, repository, worktree, and sentinel preservation evidence.
- `runner-metadata.json`: exact command, Godot version, timestamps, and process exit.
- `verification-summary.json`: the 28-check final validation result.
- `evidence-manifest.json`: immutable evidence-file hashes.

### Masculine source

- Path: `F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\bodies\masculine\rigging\attempt-0002\output\pf_humanoid_v1_masculine_body_master_rigged_mixamo_attempt_0002.glb`
- SHA-256: `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4`
- Skeleton path: `Armature/Skeleton3D`
- Rest signature: `1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda`

### Feminine source

- Path: `F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\bodies\feminine\rigging\attempt-0001\output\pf_humanoid_v1_feminine_body_master_rigged_mixamo_attempt_0001.glb`
- SHA-256: `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667`
- Skeleton path: `Armature/Skeleton3D`
- Rest signature: `fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85`

### Inspection findings

Each GLB generated a five-node scene containing one `Skeleton3D`, one `Skin`, and one skin-bearing `MeshInstance3D`. Each skeleton contains 52 bones. Bone indices, names, direct parents, and hierarchy are identical. The generated root `Node3D` name, which reflects the source filename, is the only node-tree identity difference.

No duplicate or empty bone names, non-finite local rests, non-finite bind poses, unresolved numeric binds, multiple skeletons, or multiple skins were detected. Each skin has 52 binds whose numeric `bind_bone` values cover indices `0` through `51` exactly once.

All 52 `bind_name` values are empty in both imported skins. Numeric binding is complete and deterministic, but the current `HumanoidRigContract.validate_mapped_rig()` rejects empty bind names. The mapped-production validator must therefore gain the bounded numeric-bind behavior defined below without weakening either legacy validator.

All 52 local rest transforms and all 52 bind poses differ between the body candidates. Consequently, one shared source hash or rest signature would misrepresent both assets and is prohibited.

## Approved Two-Resource Architecture

Both resources retain `canonical_rig_id = &"pf_humanoid_v1"`. That ID describes Party Forge's semantic humanoid contract; it does not assert a shared source pose.

### Masculine mapping

- `mapping_id`: `&"pf_humanoid_v1_mixamo52_masculine"`
- Path: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres`
- `source_skeleton_sha256`: `8f589e35f16f02fe4aa0f45b5f2c85377a41f9ecc188670bf59159518e6cdbe4`
- `source_rest_signature`: `1ea73d190881c437d8ca6fc10dd7c4f446d2d14523416bcd0731264dad689eda`

### Feminine mapping

- `mapping_id`: `&"pf_humanoid_v1_mixamo52_feminine"`
- Path: `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres`
- `source_skeleton_sha256`: `173198e3d044418b9765971e8b698664176c05dadd6a5aaa4ddb8df8d4c08667`
- `source_rest_signature`: `fad7e1860ef45781179d156654734b6160a7d97df96be43d3eb8c0bc51ea5c85`

No resource named `pf_humanoid_v1_mixamo52.tres` may be created as a fallback or alias. A missing body-specific mapping fails closed.

## Shared 19-Role Semantic Mapping

Both body-specific resources use this exact mapping:

| Party Forge role | Bone index observed | Exact bone name | Required ancestor role |
|---|---:|---|---|
| `hips` | 0 | `mixamorig_Hips` | none |
| `spine` | 9 | `mixamorig_Spine` | `hips` |
| `chest` | 11 | `mixamorig_Spine2` | `spine` |
| `neck` | 31 | `mixamorig_Neck` | `chest` |
| `head` | 32 | `mixamorig_Head` | `neck` |
| `upper_arm_left` | 13 | `mixamorig_LeftArm` | `chest` |
| `lower_arm_left` | 14 | `mixamorig_LeftForeArm` | `upper_arm_left` |
| `hand_left` | 15 | `mixamorig_LeftHand` | `lower_arm_left` |
| `upper_arm_right` | 34 | `mixamorig_RightArm` | `chest` |
| `lower_arm_right` | 35 | `mixamorig_RightForeArm` | `upper_arm_right` |
| `hand_right` | 36 | `mixamorig_RightHand` | `lower_arm_right` |
| `upper_leg_left` | 1 | `mixamorig_LeftUpLeg` | `hips` |
| `lower_leg_left` | 2 | `mixamorig_LeftLeg` | `upper_leg_left` |
| `foot_left` | 3 | `mixamorig_LeftFoot` | `lower_leg_left` |
| `toe_left` | 4 | `mixamorig_LeftToeBase` | `foot_left` |
| `upper_leg_right` | 5 | `mixamorig_RightUpLeg` | `hips` |
| `lower_leg_right` | 6 | `mixamorig_RightLeg` | `upper_leg_right` |
| `foot_right` | 7 | `mixamorig_RightFoot` | `lower_leg_right` |
| `toe_right` | 8 | `mixamorig_RightToeBase` | `foot_right` |

`mixamorig_Spine1`, the shoulder bones, and the finger chains remain valid superset bones. They are not silently substituted for any Party Forge semantic role.

## Mapped-Production Bind Resolution

This algorithm applies only inside `HumanoidRigContract.validate_mapped_rig()`. It resolves every `Skin` bind against the exact supplied `Skeleton3D` before validating semantic roles.

For bind slot `i`:

1. Read `bind_name = skin.get_bind_name(i)`, `bind_bone = skin.get_bind_bone(i)`, and `bind_pose = skin.get_bind_pose(i)`.
2. Require `bind_pose` to be finite and invertible under the existing `MIN_INVERTIBLE_DETERMINANT` threshold. Failure records an error for slot `i`.
3. Require `bind_bone` to be in `[0, skeleton.get_bone_count())`. A missing or out-of-range numeric index fails. A name never compensates for an invalid numeric index.
4. Resolve the numeric index directly to exactly one skeleton bone. Record that bone index in a coverage map. If another bind slot already resolved to the same bone index, both coverage and identity are ambiguous, so validation fails.
5. If `bind_name` is empty, the valid numeric index is authoritative for that slot. The empty name is not an error.
6. If `bind_name` is present, find every skeleton bone whose name exactly equals it. The name must resolve to exactly one bone, and that bone's index must equal `bind_bone`. Zero matches, multiple matches, or a name/index mismatch fails. The name does not override the numeric index.
7. After all slots are processed, require complete one-to-one skeleton coverage: every skeleton bone index must appear exactly once in the coverage map. A missing skeleton bone, duplicate resolved bone, unresolved slot, or extra invalid slot fails.
8. For each of the 19 semantic roles, require its mapped bone name to occur exactly once in the skeleton, require the mapped bone index to appear in the resolved bind coverage, require its local rest to be finite and invertible, and require its approved ancestor role to be an actual ancestor.

Validation accumulates deterministic errors rather than accepting a partially valid skin. Parser order is bind-slot order followed by canonical `REQUIRED_ROLES` order, so identical invalid inputs produce identical error ordering.

### Fail-closed cases

The mapped-production validator rejects all of the following:

- missing `Skeleton3D`, `Skin`, mapping, semantic role, or mapped bone;
- empty or duplicate target bone names in the 19-role mapping;
- numeric bind indices below zero or outside the skeleton;
- two bind slots resolving to the same skeleton bone;
- incomplete skeleton-bone coverage;
- a present bind name with zero or multiple skeleton matches;
- a present bind name that resolves to a different index than `bind_bone`;
- non-finite or non-invertible bind poses;
- non-finite or non-invertible mapped rests;
- an invalid required ancestor relationship;
- a mapping source hash or rest signature that does not match the selected body-specific identity.

## Validator Separation

The three validation paths have different compatibility promises:

1. `HumanoidRigContract.validate_rig()` remains the exact legacy 19-bone validator. Its topology, rest, pivot, and direct-parent behavior must not change.
2. `HumanoidRigContract.validate_skin()` remains the strict legacy named-bind validator. Numeric-only or unnamed binds continue to fail there.
3. `HumanoidRigContract.validate_mapped_rig()` is the only path allowed to accept unnamed imported binds, and only through the complete numeric resolution algorithm above.

No helper shared with the legacy validators may change their externally observed errors or acceptance behavior. New mapped-bind helpers must be private to the mapped-production path unless tests prove legacy behavior byte-for-byte unchanged.

## Deterministic Source and Rest Identity

`source_skeleton_sha256` is the lowercase SHA-256 of the complete immutable source GLB bytes. It is provenance, not a claim that the masculine and feminine GLBs are interchangeable.

`source_rest_signature` uses the inspection's `production-skeleton-rest-v1` serialization contract. That phrase names the algorithm in this design; it is not serialized as a header and contributes no bytes to the two approved evidence hashes:

1. Iterate all skeleton bones in numeric index order.
2. For each bone, serialize `index|exact_name|direct_parent_index|transform`.
3. Serialize the local-rest `Transform3D` as 12 comma-separated fixed-nine-decimal components in this order: `basis.x`, `basis.y`, `basis.z`, then `origin`, with each vector in `x,y,z` order.
4. Join bone records with `\n`, add no trailing newline, encode as UTF-8, and compute lowercase SHA-256.

The implementation must reproduce the two approved evidence signatures exactly before either mapping resource can be written. A mismatch fails closed and requires a new inspection/approval gate; the implementation may not update the resource to make the mismatch disappear.

The source GLB SHA cannot be derived from a live `Skeleton3D`. The later asset-qualification/import gate must compare the resource's `source_skeleton_sha256` to the immutable file or manifest source hash, while `validate_mapped_rig()` recomputes and verifies the live skeleton's rest signature.

## Body-Preset Resource Selection

Selection belongs to the presentation layer and must not change gameplay character, class, profile, item, ability, or save-data IDs.

A presentation-only `HumanoidRigMappingCatalog` will expose one operation:

`resolve(body_preset_id: StringName) -> HumanoidRigMapping`

Its complete lookup table is:

| `body_preset_id` | Required mapping resource |
|---|---|
| `&"masculine"` | `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_masculine.tres` |
| `&"feminine"` | `data/presentation/humanoid_rigs/pf_humanoid_v1_mixamo52_feminine.tres` |

The presentation body's selected preset, including `CharacterVisualProfile.default_body_preset` during initial activation and the requested preset during a body-preset transaction, is the sole lookup key. Class/profile IDs do not participate in rig selection.

Before committing a prepared body-preset change, the presentation layer must:

1. resolve the exact mapping for the requested preset;
2. require the expected resource ID and `canonical_rig_id`;
3. validate the selected body's skeleton and skin with that mapping;
4. require the body's approved source provenance and recomputed rest signature to match the mapping;
5. commit the visual swap only after all checks pass.

An unknown preset, missing resource, wrong resource ID, wrong canonical ID, wrong source hash, wrong rest signature, or failed mapped-rig validation rejects the prepared change. There is no cross-body or shared-resource fallback. The existing fallback presentation/error channel remains responsible for keeping the UI usable; validation failure must not mutate the prior active body.

## Error and Provenance Reporting

Errors must identify the body preset, mapping ID, source hash or signature field, bind slot or semantic role, and exact failure category. Logs may include repository-relative resource paths but must not embed machine-specific staging paths in production resources or manifests.

The two external paths in this document are evidence provenance only. Later production resources store lowercase SHA-256 values and repository-relative references. Acquisition/generation records, immutable attempt identity, inspection evidence path, Godot version, and approval date remain in QA documentation or manifest provenance rather than runtime gameplay IDs.

## Test Requirements

The separately approved TDD contract amendment must begin with trustworthy failing tests and cover at least:

- the inspected 52-bone topology with 52 unnamed, complete numeric binds passes `validate_mapped_rig()`;
- the same input still fails strict legacy `validate_skin()` and the superset skeleton still fails exact legacy `validate_rig()`;
- named binds with agreeing numeric indices pass;
- an empty name plus a valid unique numeric index passes;
- negative and out-of-range numeric indices fail;
- duplicate numeric bone coverage fails;
- incomplete skeleton coverage fails;
- a present name with no skeleton match fails;
- a present name with duplicate skeleton matches fails;
- a present name whose resolved index conflicts with `bind_bone` fails;
- non-finite and non-invertible bind poses fail;
- non-finite and non-invertible mapped rests fail;
- missing mapped binds, mapped bones, semantic roles, and required ancestors fail;
- masculine and feminine fixtures produce their exact distinct rest signatures;
- selecting `masculine` and `feminine` returns only their exact resources;
- an unknown preset and any cross-body resource mismatch fail without mutating the active presentation;
- all pre-existing legacy validator tests retain their existing acceptance and errors.

Focused mapped-rig suites, legacy rig/skin suites, body-region and skinned-equipment regressions, the full headless suite, and `git diff --check` must pass with their standard terminal markers before the contract checkpoint is eligible for approval.

## Migration and Rollback

The implementation sequence is intentionally split:

1. Approve this written amendment.
2. Write and approve a TDD implementation plan that reconciles the original plan's singular-resource references.
3. Implement only the mapped-production numeric-bind algorithm, deterministic rest-signature verification, and presentation-only body-preset resolver. Preserve both legacy validators.
4. Verify and commit that contract amendment without creating either `.tres` resource.
5. Obtain a new approval naming the exact two resource writes.
6. Create the masculine and feminine mapping resources from the approved hashes, signatures, and 19-role table; validate each against its exact candidate in a bounded gate.
7. Only after resource validation may a later, separately approved body qualification or integration plan consume them.

Before any production integration, any manifest field whose name or semantics assume named-only binds must be amended explicitly. Numeric-bind acceptance in `validate_mapped_rig()` does not silently redefine existing manifest schema fields such as `skin_named_bind_sha256`.

Rollback is commit-based. Reverting the contract-amendment commit restores the current named-bind-only mapped validator. Reverting the later resource commit removes both mappings together. The immutable source GLBs require no rollback because neither phase may modify them. Downstream integration cannot begin before both commits have independent approval, preventing partial resource adoption.

## Exclusions

This amendment does not authorize or include:

- creation of either mapping resource or a shared mapping resource;
- code or test changes;
- edits to the original implementation plan;
- GLB copying, mutation, renaming, re-export, bind-name injection, or rest-pose normalization;
- Godot import into Party Forge, cache generation, runtime integration, or visual preview;
- Blender, 3D Gen Studio, geometry, rigging, weights, UVs, materials, textures, heads, armor, or equipment work;
- Task 4 body qualification, manifests, scenes, or asset promotion;
- gameplay ID, save schema, balance, class, item, ability, or progression changes;
- merge, push, rebase, cleanup, deletion, or publication.

## Approval Gates

1. **Written-spec review:** Jacob reviews this committed amendment. No implementation follows automatically.
2. **Implementation-plan approval:** a new plan must name exact code/test files, RED/GREEN commands, containment, and rollback.
3. **Contract checkpoint approval:** numeric-bind and rest-signature code passes focused, regression, and full-suite verification and is committed without `.tres` files.
4. **Two-resource write approval:** Jacob separately authorizes the exact masculine and feminine resource paths and values.
5. **Resource validation approval:** each resource validates against its own immutable candidate, source hash, native rest signature, bind coverage, and semantic mapping.
6. **Task 4 or integration approval:** body qualification and production integration remain separate later scopes.

Failure at any gate leaves both immutable GLBs and the currently approved Task 3 checkpoint unchanged.
