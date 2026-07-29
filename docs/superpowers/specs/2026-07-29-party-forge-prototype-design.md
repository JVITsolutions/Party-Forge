# Party Forge Five-Minute Prototype Design

## Purpose

Party Forge is a three-dimensional, top-down survivor game in which recruitable fantasy party members replace conventional weapons. The player directly moves one class-based leader. The leader and all companions attack automatically, so play centers on positioning, survival, recruitment, and party composition.

This first milestone is a complete five-minute vertical slice. It must prove the core run loop with placeholder visuals before final character art, animation, sound, and broader content production begin.

## Approved Scope

The prototype includes:

- A fixed high-angle 3D camera that follows the leader.
- A five-minute continuous run followed by a boss encounter.
- Four playable classes: Fighter, Ranger, Mage, and Cleric.
- A maximum party size of four characters, including the leader.
- Duplicate classes.
- Automatic attacks for every party member.
- Role-based elastic companion formation.
- Experience drops, level-ups, recruitment, class ranks, shared upgrades, and overlapping trait synergies.
- Companion health, downing, and automatic revival.
- Two regular enemy behaviors and one boss.
- Placeholder models, effects, health displays, and interface elements.
- A developer sandbox for testing party and enemy combinations.
- Automated rules tests and a complete manual run check.

The design must not hard-code four formation slots, four classes, or trait tiers that stop at four. Those are prototype content limits, not architectural limits.

## Out of Scope

The first prototype does not include:

- Final art, animation, music, or sound production.
- Equipment, weapons, loot affixes, inventory, shops, or persistent metagame progression.
- Manually activated combat abilities.
- Environmental obstacles or procedural arena generation.
- More than four class definitions.
- A party larger than four during ordinary prototype runs.
- Online features or multiplayer.
- Controller support as an acceptance requirement. Movement uses Godot input actions so controller mappings can be added without changing player code.

## Run Flow

1. The player chooses Fighter, Ranger, Mage, or Cleric as the leader.
2. A continuous five-minute arena run begins.
3. The player moves the leader with directional input. Every attack and class ability activates automatically.
4. Defeated enemies drop experience orbs. Orbs move toward the leader inside the collection radius.
5. Gaining a level pauses the run and presents three valid choices.
6. While the party has fewer than four characters, at least one choice is a recruit. Other valid choices may improve an owned class, an active trait, or a shared party statistic.
7. Once the party is full, recruitment choices are replaced by class-rank, active-trait, or shared-stat upgrades.
8. Enemy quantity and composition escalate throughout the timer.
9. At five minutes, routine spawning slows and the Forge Guardian boss appears.
10. The run ends in victory when the Forge Guardian dies or in defeat when the leader dies.

The level-up generator must never present a recruit when the party is full, an upgrade for an unowned class, or a trait upgrade that cannot affect the current party. If a category has too few valid options, another valid category fills the choice slot.

## Party Rules

The leader is a normal member of the party and carries the complete statistics, attacks, class rank, and traits of the selected class. Player input replaces only the leader's formation movement; it does not replace automatic target selection or attacks.

All party members have health. When a companion reaches zero health, that companion becomes downed, stops moving and attacking, and revives after a data-defined delay. Healing cannot affect a downed companion unless a later upgrade explicitly enables it. When the leader reaches zero health, the run ends immediately.

The prototype party cap is four total characters. Duplicate classes occupy separate party positions but share the run-specific rank of that class. Recruiting a second Fighter therefore gains the current Fighter rank immediately.

## Classes

### Fighter

- Traits: `Martial`, `Vanguard`.
- High health and armor.
- Prefers the frontline and intercepts nearby enemies approaching the party.
- Uses a short-range cleaving attack.

### Ranger

- Traits: `Martial`, `Ranged`.
- Prefers medium distance.
- Fires rapid single-target projectiles.
- Prioritizes enemies closest to the party.

### Mage

- Traits: `Arcane`, `Ranged`, `Caster`.
- Prefers long distance.
- Launches slower area attacks at enemy clusters.

### Cleric

- Traits: `Divine`, `Support`, `Caster`.
- Prefers the protected center of the formation.
- Periodically heals the living party member with the greatest missing-health percentage.
- Uses a modest ranged holy attack while healing is unavailable or unnecessary.

All class values, including health, movement, attack range, damage, cooldowns, tether distance, and class-rank scaling, live in Godot `Resource` data rather than class-specific controller code.

## Formation and Movement

Companions use role-based elastic formation. Each class defines a preferred distance band, engagement distance, and maximum tether distance relative to the leader.

A companion may leave its preferred band to attack, intercept, heal, or avoid overlap. It returns toward the leader when it has no valid action or exceeds its tether. Local separation prevents party members from occupying the same space. Formation behavior operates on an arbitrary collection of companions and does not rely on fixed party-slot coordinates.

The first arena is a flat, bounded rectangle without obstacles. This keeps steering deterministic enough to evaluate class behavior before navigation around complex geometry is introduced.

## Progression and Traits

Class rank is shared by all members of the same class for the current run. A Fighter-rank upgrade affects all current Fighters and any Fighters recruited later.

Trait counts are calculated from living and downed party members; a temporary downed state does not remove a build synergy. The prototype defines trait tiers at two and four matching members. Trait evaluation accepts higher thresholds in data so later rosters can add tiers at six, eight, and beyond.

Initial trait directions include:

- `Martial`: attack-speed improvements for Martial members.
- `Ranged`: projectile-speed and range improvements for Ranged members.
- `Caster`: reduced ability cooldowns for Caster members.
- `Vanguard`: defensive protection for allies near Vanguard members.
- `Divine`: stronger healing and shorter companion revival delays.
- `Support`: stronger non-damage effects.
- `Arcane`: stronger area damage or area size.

The exact values are balance data, not fixed design requirements. The required behavior is that thresholds activate and deactivate correctly as party composition changes, duplicates count, multiple overlapping traits can be active simultaneously, and the user interface clearly reports newly activated tiers.

## Arena and Camera

The arena scene is a saved version of the current flat-floor concept with an explicit floor mesh, collision, boundaries, player spawn, enemy spawn region, and camera limits.

The camera uses a fixed high-angle 3D perspective. It follows the leader smoothly, does not rotate, and requires no camera input. Framing must show enough space ahead of movement to read incoming enemies while keeping the party distinguishable.

The current arena exists only as an unsaved editor scene. Implementation must save or reconstruct it as a named arena scene before other scenes depend on it.

## Enemies and Boss

### Swarmer

- Fast, fragile melee pursuer.
- Spawns in groups.
- Applies pressure through numbers and tests melee interception.

### Spitter

- Slower ranged enemy.
- Stops at a preferred distance.
- Fires visible, dodgeable projectiles.
- Repositions if the party gets too close.

### Forge Guardian

The boss appears when the five-minute timer expires. It has three clearly telegraphed behaviors:

- A targeted charge toward the leader's recent position.
- A close-range shockwave with a visible danger area.
- A summon action that creates a small Swarmer group.

Normal spawning slows during the boss encounter but does not need to stop completely. Defeating the Forge Guardian triggers the victory state.

## Visual Communication

All prototype entities use simple colored 3D shapes. The prototype requires consistent visual language rather than final presentation:

- Each class has a distinct color and silhouette.
- Friendly, hostile, healing, damage, experience, and danger effects are immediately distinguishable.
- Health, downed state, trait activation, level-up pause, timer, boss arrival, victory, and defeat are visible without reading debug output.
- Projectiles and boss telegraphs remain readable from the approved camera angle.

## Technical Architecture

The implementation uses typed GDScript and small systems with explicit responsibilities:

- `GameRun` owns run state, timer, difficulty escalation, victory, and defeat.
- `PartyManager` owns recruitment, the party cap, class ranks, trait counts, and party-level signals.
- `ExperienceSystem` owns drops, collection, level thresholds, and choice generation.
- `Leader` translates directional input into movement.
- `Companion` delegates movement decisions to a formation agent.
- `FormationAgent` selects desired positions from class role, target, and tether data.
- `HealthComponent` owns damage, healing, downing, revival, and death signals.
- `AttackController` owns target selection, cooldowns, and attack execution.
- `SpawnDirector` owns time-based enemy composition and boss arrival.
- `ClassDefinition`, `AttackDefinition`, `EnemyDefinition`, `TraitDefinition`, and `UpgradeDefinition` are Godot `Resource` types.

Systems communicate through typed methods and signals. A controller must not search arbitrary scene-tree paths for another system's internal node. Missing required resource references fail early with a clear error. Invalid optional choices are excluded from the level-up pool instead of producing unusable cards.

## State and Data Flow

The principal run flow is:

1. `GameRun` creates the selected leader and initializes `PartyManager`.
2. `SpawnDirector` reads run time and creates enemies from resource definitions.
3. Attacks send damage to `HealthComponent` instances.
4. Enemy death emits a reward event that creates experience.
5. Experience collection updates `ExperienceSystem`.
6. A level threshold pauses gameplay and requests valid choices from party and upgrade data.
7. The selected choice updates party composition, class rank, trait state, or shared statistics.
8. `PartyManager` recalculates active trait tiers and emits changes for combat systems and interface feedback.
9. Leader death, boss death, or the boss trigger time advances `GameRun` to the corresponding state.

## Error Handling

- A missing required scene or core definition stops the run at startup with a grep-friendly error naming the missing resource path.
- A malformed optional upgrade is excluded and logged without corrupting the run.
- The level-up screen validates that exactly three usable choices exist before pausing. If content data cannot satisfy that contract, it uses known-safe shared-stat fallbacks.
- Repeated damage cannot down or kill the same entity more than once.
- A downed companion cannot move, attack, heal, collect experience, or be selected as an ordinary healing target.
- Run-end transitions are idempotent so victory and defeat cannot both trigger.
- Projectiles and temporary effects clean themselves up at their lifetime or when the run ends.

## Testing and Completion Evidence

Automated headless checks cover:

- Damage, armor, healing, downing, revival, and leader death.
- Duplicate recruitment and the four-character total cap.
- Shared class ranks for existing and later recruits.
- Overlapping trait counts and two- and four-member thresholds.
- Valid level-up choice generation before and after the party is full.
- Target selection and attack cooldown rules.
- Five-minute boss triggering and mutually exclusive victory and defeat.
- Missing-resource and invalid-upgrade handling.

A developer sandbox permits explicit spawning of leaders, companions, regular enemies, and the boss without waiting through a normal run.

Manual acceptance requires recorded evidence of:

1. A complete five-minute run launched from the project main scene.
2. Recruitment to a four-character party, including at least one duplicate class.
3. Activation of at least two overlapping traits.
4. A companion being downed and reviving.
5. Both regular enemy behaviors appearing.
6. The Forge Guardian appearing at five minutes.
7. A boss victory outcome.
8. A separate leader-death defeat outcome.
9. No parser errors or runtime errors in the Godot output during the accepted runs.

## Repository Baseline

The Party Forge project was not a Git repository when design began. The approved documentation milestone initializes Git, ignores Godot's generated `.godot/` directory and the visual companion's `.superpowers/` directory, and commits the existing Godot project baseline with this design document. Gameplay implementation begins only after the user reviews this written specification.
