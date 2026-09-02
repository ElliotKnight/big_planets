# Big Planets — Core Mechanics

A turn-based 4X strategy game played on a small, square, procedurally generated grid of tiles. Players start with a single city and expand an empire by exploring, growing cities, researching technology, and fighting rival tribes. Matches are short compared to most 4X games.

## Turn Structure

The game is turn-based. On each turn a player may move and act with every unit they control and spend accumulated stars. There is no per-turn action limit beyond what units and stars allow, so a turn ends when the player chooses to pass. Play then passes to the next player (or AI). Everything a player does in a turn happens before the opponent acts.

## Stars (Economy)

**Stars** are the single currency. They are spent on technology, city upgrades, unit training, and terrain actions.

- Stars are generated **at the start of each turn**, based on the player's total city income.
- Each city produces stars equal to its **population-driven level plus any workshop bonus**; the empire's total per-turn income is the sum across all cities.
- Stars are banked and carry over between turns, so players can save up for expensive purchases.
- Income growth is the central economic engine: bigger, higher-level cities generate more stars, which fund faster expansion and stronger armies.

## Cities and Population

Cities are the core of the economy and the only place units are trained.

- Every city has a **level** and a **population** counter. Adding population fills a track; when the track fills, the city **levels up**.
- Population is added by harvesting resources, building improvements, and capturing territory near the city.
- **Leveling up** grants a reward, and the player usually chooses between two options at each level. Typical rewards include extra stars immediately, a population boost, a resource/defensive structure, a city wall, a park, a "Giant" super-unit, or increased border growth.
- Higher-level cities produce more stars per turn and can hold more units for defense.
- **Border expansion**: as a city grows it claims adjacent tiles into its territory. Resources must be inside a city's borders to be used.

## Territory and Tiles

The map is a grid of tiles, each with a terrain type: field/ground, forest, mountain, shallow water (ocean), and deep water. Terrain governs movement and what can be built.

- Tiles belong to a city's **territory** once claimed. Actions on a tile (harvesting, clearing, building) generally require it to be within your borders.
- Terrain restricts movement: mountains cost extra to enter and block some units; water requires naval capability.
- **Fog of war**: the map starts hidden. Moving units and founding cities reveals surrounding tiles. Exploration is one of the primary early-game activities.

## Resources

Resources sit on specific terrain and are exploited (usually after researching the relevant technology) to add population or stars to the owning city.

- **Fruit** — on fields; harvested for population.
- **Animals (game)** — in forests; hunted for population.
- **Fish** — in shallow water; caught for population.
- **Crops (farms)** — built on fields; add population via farming tech.
- **Metal (ore)** — in mountains; mined for population/stars.
- **Forests** can be cleared for a small star gain or used to build **lumber huts**; forests can also be grown on empty fields with the right tech.

Harvesting a resource typically costs stars and adds population to the nearest city, feeding the level-up track.

## Technology (Tech Tree)

Research is bought with stars and permanently unlocks new abilities for the whole empire.

- The tech tree is arranged in branches, each starting from a core technology and deepening into more advanced ones.
- Later technologies in a branch cost more; **cost scales with the number of cities you own**, so a larger empire pays more per tech.
- Technologies unlock terrain actions (harvesting fruit, mining, fishing, farming), city improvements, movement abilities (crossing water, climbing mountains), and new unit types.
- Choosing a research path is a core strategic decision, since stars spent on tech cannot be spent on units or growth.

## Units and Combat

Units are trained in cities for stars and are the only means of fighting and defending.

**Core unit attributes:**
- **Attack** and **defense** values.
- **Health (HP)**, which persists between turns and can regenerate.
- **Movement** range (tiles per turn).
- **Attack range** (melee = adjacent; ranged units strike from a distance).

**Combat rules:**
- Combat is initiated by moving a unit to attack an adjacent (or in-range) enemy.
- Damage dealt depends on the attacker's attack stat, the defender's defense stat, and the defender's current HP; stronger relative stats and higher HP mean more damage dealt and less taken.
- **Retaliation**: when a melee attacker doesn't kill its target, the defender strikes back. Ranged units and certain situations avoid retaliation.
- **Defense bonuses**: defending in a city, behind walls, or on favorable terrain (e.g., forests, mountains) increases a unit's effective defense.
- **Veteran units**: a unit that survives enough kills can be promoted, gaining a permanent HP increase (and can be healed to the new maximum).
- **Healing**: units recover HP by resting inside friendly territory; some abilities or improvements speed this up.

**Common unit roles** include cheap scouts/melee infantry, ranged attackers, defensive units, cavalry-style fast units, siege units effective against cities, and naval units for water combat. Land units generally need to embark to cross water (unlocked by tech) and become naval units while at sea.

## Capturing Cities

- Enemy and neutral (village) tiles can be **captured** by moving a unit onto them and using the capture action, which usually takes a turn during which the unit cannot also attack.
- Villages become new cities under your control; captured enemy cities transfer their level and territory to you.
- Capturing is the primary way to expand aggressively and to win by elimination.

## Win Conditions and Game Modes

- **Domination**: eliminate all other tribes by capturing or destroying their cities. The last tribe standing wins.
- **Perfection (score mode)**: a single-player mode with a fixed turn limit (commonly 30 turns). When the limit is reached, the game scores your empire, rewarding city development, technology, territory, and population. The goal is the highest possible score, making it an optimization puzzle rather than a fight to the death.
- **Score/points multiplayer**: similar scoring applied to competitive play with a turn cap.

**Scoring** rewards empire development broadly: number and level of cities, technologies researched, territory controlled, and units. Growth and efficient use of stars drive a high score.

## Strategic Summary

The whole game reduces to a loop: **generate stars → invest them in tech, city growth, and units → expand territory and capture cities → generate more stars.** Every decision is a trade-off in how to spend a limited pool of stars each turn, and success comes from compounding economic growth faster than opponents while defending what you hold.
## Running the First Draft (Godot 4.7)

The playable prototype lives in this folder as a Godot project. It launches **fullscreen** (press `F11` to toggle windowed mode) and scales its interface for Retina displays.

1. Open Godot 4.7, choose **Import**, and select `project.godot` in this directory (or drag the folder onto the Godot project manager).
2. Press **F5** (Run Project). Pick a mode, map size and number of AI opponents, then **Start game**.

From a terminal, the same thing:

```
/path/to/Godot.app/Contents/MacOS/Godot --path .
```

**Look and feel**

Buildings, trees, rocks, flags and siege engines come from Kenney's Castle Kit (CC0, `assets/kit`, credit: www.kenney.nl); its palette-variation textures give each tribe its own roof and flag colour. The rest of the presentation borrows the aesthetic of the `goodlife` habit tracker: the map is a floating low-poly island in space, built from flat-shaded primitives with no art assets. Checkerboard grass caps sit on dirt bases; forests are oak, pine and cherry trees; mountains are snow-capped peaks with glowing ore crystals; water tiles are glossy blue slabs with fish. Every tile keeps its centre clear (trees sit at the back of forest tiles, mountains have a front ledge, animal tiles are fenced paddocks with sheep) so units always stand in view. Cities are cottages that gain chimneys, extensions and second floors as they level, with windows glowing in the tribe colour. Around the island: an additive starfield, nebula glows, three alien planets (one ringed, one with a moon) and shooting stars. Lighting is a warm sun with cyan and pink rim lights, ACES tonemapping and bloom. The HUD uses frosted-glass panels in the same dark neon palette.

**Animation and sound**

Every game event is queued and replayed as an animation. Units are rigged little people (hips, shoulders, neck) with faces, hair and type-specific gear: they walk tile by tile along their path with swinging legs, melee attackers raise their weapon and lunge, archers raise the bow, draw the string and loose a real arrow, catapults fling a boulder, damage numbers float up, killed units burst into sparks, and captured cities send a glowing ripple across every tile of their new territory. AI turns are replayed the same way, so you watch rivals move and fight (only in explored tiles). Trees sway, banners flutter, sheep hop, fish wobble and units idle-bounce. Star income flies from each city into the star counter at the start of your turn. The tech tree opens as a branching diagram. All sound effects are synthesised in code at startup (`scripts/sfx.gd`), so there are no audio files and nothing to license.

**Controls**

- Left-click one of your units to select it. Green tiles are reachable this turn; red-highlighted enemies can be attacked.
- Click a tile inside your borders to see harvest/build actions in the right panel. Click a city to train units.
- A unit that starts its turn on a village or enemy city can **Capture** it from the right panel.
- Drag with the left mouse button to orbit the island, scroll (or pinch) to zoom, arrow keys also orbit.
- `Space` ends the turn, `T` opens the tech tree, `Tab` cycles idle units, `Esc`/right-click clears the selection, `F11` toggles fullscreen.

**Layout**

| Path | What it holds |
| --- | --- |
| `scripts/defs.gd` | Terrain, resource, unit, tech and level-reward tables. Tune numbers here. |
| `scripts/map_gen.gd` | Procedural island map, capitals, villages and resources. |
| `scripts/game.gd` | Rules engine: turns, stars, cities, movement, combat, capture, tech, scoring. |
| `scripts/ai.gd` | Greedy AI opponent. |
| `scripts/models.gd` | Low-poly mesh factory: rigged units, sheep, crops, fruit, water details. |
| `scripts/kit.gd`, `assets/kit/` | Kenney Castle Kit loader and models (trees, castles, walls, flags, rocks, siege). |
| `scripts/space.gd` | Space backdrop: stars, nebulae, planets, shooting stars. |
| `scripts/map_view_3d.gd` | 3D island, lighting, highlights, orbit camera and tile picking. |
| `scripts/ui_theme.gd`, `scripts/glass_panel.gd`, `shaders/` | Neon glass UI theme and shaders. |
| `scripts/tech_tree_panel.gd` | Branching tech-tree diagram. |
| `scripts/sfx.gd` | Procedurally synthesised sound effects. |
| `scripts/main.gd` | HUD, menus, selection and input. |
| `tests/smoke.gd` | Headless AI-vs-AI run: `Godot --headless --path . --script tests/smoke.gd` |
