# Dawn Bulwark Plate Fit Proof Design

**Status:** Approved in conversation on 2026-08-26.

## Purpose

Prove that one Sunweld Bastion interpretation of `dawn_bulwark_plate` can remain a single gameplay item while supporting distinct masculine and feminine fitted meshes on the validated Party Forge humanoid rigs.

This is a bounded asset-pipeline proof. It does not authorize production retopology, the other ten Sunweld Bastion items, Party Forge import, prototype-asset replacement, or Blender work.

## Relationship to the pilot

This design is a focused execution slice of `docs/specs/2026-08-23-modular-equipment-pilot-design.md`. The existing body working masters and their validated 52-bone Mixamo-compatible rig derivatives remain unchanged. The Party Forge checkout remains outside the asset-generation and fitting loop.

## Art direction

The plate uses an articulated heavy-cuirass silhouette:

- fitted cuirass and backplate;
- a separate collar;
- separate, modest left and right pauldrons;
- layered waist plates;
- dominant charcoal forged steel;
- restrained antique-gold edges and fasteners;
- warm-ivory articulation gaps; and
- small amber sun-rune accents.

The armor should read as durable paladin equipment from Party Forge's high-angle camera without using oversized pauldrons or dense micro-detail.

## Hybrid reference strategy

Create two coordinated reference groups:

1. An equipped concept on the masculine T-pose working master, used only to establish scale, shoulder location, waist location, clearance, and silhouette.
2. Isolated armor-only front, rear, profile, and three-quarter references showing an empty wearable shell.

Only the isolated armor references are eligible as 3D-generation inputs. The equipped concept is a validation overlay, not a mesh-generation source. This reduces the chance that body geometry becomes fused into the armor.

The references must agree on component boundaries, material placement, proportions, and decoration. A concept attempt fails if the equipped and isolated views imply different constructions.

## Armor-only master

Generate multiple high-detail armor-only candidates as immutable attempts. Preserve the prompt, workflow, settings, seed where available, source hashes, output hashes, and mesh statistics for each attempt.

The selected working master keeps these logical sections distinct beneath the single `dawn_bulwark_plate` identity:

- cuirass;
- backplate;
- collar;
- left pauldron;
- right pauldron; and
- layered waist plates.

The master must contain no humanoid body mesh. Before fitting, review it from at least eight exterior turntable angles and inspect the interior, collar opening, shoulder openings, waist opening, face orientation, disconnected components, duplicate/internal shells, and wireframe.

This proof may retain high-detail topology. Triangle and material counts are recorded, but the final runtime budget is not enforced until production preparation.

## Body-fit derivatives

Preserve the selected armor-only master unchanged. Derive one masculine fit and one feminine fit from that same source. The fits must retain the same design, component organization, materials, motifs, and gameplay identity; they may change only as needed to follow the approved body silhouettes and clear deformation surfaces.

Skin both derivatives to the respective validated 52-bone Mixamo-compatible body rigs. The cuirass, backplate, collar, pauldrons, and waist plates participate in the shared skin. Restrict pauldron weighting primarily to the clavicle, shoulder, and upper-arm region so the plates remain visually rigid while following arm motion.

No Blender work is authorized for this proof. If the available automated fitting and skinning route cannot produce an acceptable result, preserve the evidence and stop for a new user decision instead of silently changing tools or reconstructing the armor manually.

## Deformation review

Review both fitted derivatives in:

- neutral pose;
- walk support and passing poses;
- forward arm raise;
- overhead arm raise;
- torso twist; and
- a representative melee stance.

Inspect the collar, armpits, shoulder guards, chest, back, and waist from front, three-quarter, side, rear, diagnostic close-up, and Party Forge high-angle views.

The proof passes visually only when both fits:

- preserve the same recognizable armor silhouette;
- contain no fused body geometry;
- avoid major clipping or floating components;
- keep the warm-ivory articulation gaps readable; and
- deform without structural collapse or obvious pauldron inversion.

Minor topology cleanup and final weight-paint polish may remain for production preparation. Structural fit failures do not pass.

## Outputs and provenance

All generated outputs remain beneath the external pilot staging root:

`F:\Projects(root)\Game dev\Projects\party-forge-asset-staging\modular-equipment\pilot-0001\`

The proof produces:

- immutable equipped and isolated concept attempts;
- immutable raw 3D candidates;
- one selected armor-only working master;
- masculine and feminine fitted, rigged GLB derivatives;
- standalone eight-angle review evidence;
- equipped pose and diagnostic review evidence for both bodies; and
- one approval record linking each derivative to exact source hashes.

Reviewed attempts are never overwritten. A rejected concept, generation, fit, or skinning result receives a new attempt number and remains preserved with its failure reason.

## Automated validation

Validation must fail closed on:

- invalid GLB structure or non-finite transforms;
- missing or unexpected skeleton mapping;
- absent skin data;
- embedded humanoid body geometry;
- embedded animation libraries;
- unexpected duplicate skeletons;
- unweighted vertices;
- bone references outside the intended skeleton;
- disconnected generator debris;
- duplicate internal shells;
- inverted exterior surfaces; or
- component-identity drift between masculine and feminine fits.

The validator records triangle counts, material counts, mesh names, bone counts, source hashes, and output hashes even when an attempt fails.

## Approval and next gate

Jacob reviews the armor-only master plus both fitted derivatives using the standalone and equipped evidence. Approval of this proof authorizes planning for production retopology, body-region preparation, final UV/material work, and weight-paint polishing of the bodies and plate.

Approval does not authorize Party Forge import or production of the remaining ten Sunweld Bastion items. Those remain separate gates.
