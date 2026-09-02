# Big Planets

## Project overview

A turn-based 4X strategy game inspired by Polytopia, built in Godot 4 with GDScript. Players expand from a single city on a small procedurally generated island, harvesting resources, researching a tech tree, training units and capturing villages and rival cities. `README.md` is the design spec for the game mechanics; read it before changing rules.

## Engine and language

- Godot **4.7** (tested with 4.7.2 stable), Forward+ renderer.
- **GDScript only.** No C#, no GDExtension. Use Godot 4 GDScript syntax (typed variables, `:=` inference, lambdas, `Tween`, `Callable.bind`). Do not suggest Godot 3 APIs (`yield`, `instance()`, `KinematicBody`, etc.).
- The project launches fullscreen (`display/window/size/mode=3`) with `canvas_items` stretch at a 1440x900 base so the UI scales on Retina screens.

## Project structure

There is one scene file and everything else is built from code.

```
project.godot            Godot project settings (fullscreen, stretch, Forward+)
scenes/main.tscn         The only scene: a Node with scripts/main.gd attached
scripts/
  defs.gd                Static data tables: terrain, resources, units, techs, level rewards (class Defs)
  tile.gd, city.gd, unit.gd, player.gd   Plain RefCounted data classes
  map_gen.gd             Procedural map generation (class MapGen, static)
  game.gd                Rules engine: turns, economy, movement, combat, capture, tech, scoring (class Game)
  ai.gd                  The AI opponent (class AI)
  main.gd                Scene controller: HUD, menus, selection, input, star-flight FX
  map_view_3d.gd         3D presentation: island tiles, units, highlights, animation replay queue, orbit camera (class MapView3D)
  models.gd              Low-poly mesh factory: trees, houses, sheep, rigged unit figures, bows, arrows (class Models, static)
  space.gd               Space backdrop: starfield, nebulae, planets, shooting stars (class SpaceBackdrop)
  ui_theme.gd            Neon dark Theme builder (class UITheme)
  glass_panel.gd         Frosted-glass PanelContainer (class GlassPanel)
  tech_tree_panel.gd     Branching tech-tree diagram widget (class TechTreePanel)
  sfx.gd                 Procedurally synthesised sound effects (class Sfx)
shaders/
  glass.gdshader         Screen-blur panel background
  bar.gdshader           Billboarded HP / population bar
tests/
  smoke.gd               Headless AI-vs-AI engine test (extends SceneTree)
  debug_train.gd         Headless debugging helper for AI training decisions
goodlife/                A separate Three.js habit-tracker project. Reference only: the visual style (floating island, low-poly builders, neon UI) is copied from it. Do not modify it.
```

There are no asset files: all geometry is generated from primitives in `models.gd`, all sounds are synthesised in `sfx.gd`, and the UI is built in code in `main.gd`.

## Core architecture and conventions

**Strict split between rules and presentation.**
- `Game` (`scripts/game.gd`) owns all state and rules and never touches nodes. It is a `RefCounted`, not a Node, and is fully usable headless.
- `MapView3D` and `main.gd` only read game state and call public `Game` methods. Anything a view needs to know about happens via signals.

**Map representation.** The map is a square grid stored as `game.tiles[y][x]` (an Array of Arrays of `Tile`). Coordinates are `Vector2i(x, y)`; use `game.tile_at(x, y)` (returns `null` out of bounds) and `Game.dist(a, b)` (Chebyshev distance, 8-directional movement). World position of a tile in 3D is `MapView3D.world_pos(x, y)`; tiles are 1 unit wide and the island is centred on the origin.

**Data classes.** `Tile`, `City`, `Unit`, `Player` are plain `RefCounted` objects with public fields. A `Tile` references its `city` (a `City` whose `owner_id == -1` is a neutral village), its territory owner `owner_city`, and the `unit` standing on it. Territory ownership is derived (`tile.owner_id()` reads `owner_city.owner_id`), so capturing a city transfers its territory automatically. Fog of war is `tile.explored[player_id]`.

**Turn flow.** `Game.current` is the index of the active player. The human is always player 0 and `game.viewer` is 0. `Game.end_turn()` runs every AI player synchronously (via `game.ai.take_turn(game, player)`) and returns with the human active again. Level-ups for the human are queued in `game.pending_levelups` and resolved with `game.choose_reward(id)`; the turn cannot end while one is pending.

**Signals.** `Game` emits two kinds:
- State: `changed`, `message(text)`, `level_up_pending`, `game_over(result)`.
- Presentation events: `unit_moved(u, path)`, `unit_attacked(info)`, `unit_spawned(u)`, `city_captured(c, prev_owner, tiles)`, `stars_gained(pid, amount, source)`, `tile_worked(t, pop)`, `tech_researched(pid, id)`, `city_leveled(c)`.
Emit presentation events from `Game` before `changed`. Rules must never depend on them.

**Animation replay queue.** `MapView3D` turns presentation events into steps in `_queue` and plays them sequentially with Tweens, so AI turns are watchable. While the queue is non-empty, `refresh()` is deferred (`_dirty`) and `main.gd` blocks clicks and End Turn via `map_view.is_animating()`. When adding a new visual event: add a signal in `Game`, connect it in `MapView3D.setup()`, enqueue a step dictionary with a `kind`, and add a `_play_<kind>` function that ends by calling `_next_step()`.

**Incremental scene sync.** Tiles are rebuilt only when their signature string changes (`_tile_sig`), and unit nodes are rebuilt only when their figure signature changes (`_fig_sig`). If you add visual state to a tile or unit, add it to the corresponding signature or the change will not appear.

**Rigged units.** `Models.figure()` returns a root with a `rig` meta dictionary (`leg_l`, `leg_r`, `arm_l`, `arm_r`, `hand_l`, `hand_r`, `head`, `torso`, optionally `bow`). Weapons are children of hand nodes; animations tween pivot rotations. In hand-local space, -y points along the arm and +z is up when the arm is raised. Figures face +z; mounted figures (meta `mounted`) face +x, and `_face()` compensates.

**Balance numbers** live in `defs.gd` (unit stats, tech costs, rewards) and a few constants in `game.gd` (combat formula, healing, scoring). Change them there rather than scattering literals.

## Naming and style

- `snake_case` for variables, functions, signals and file names; `PascalCase` for `class_name`s; `UPPER_SNAKE` for constants.
- Private helpers start with `_`. Public API of `Game` has no underscore.
- Signals are named as past-tense events (`unit_moved`, `city_captured`) or plain nouns for state (`changed`).
- Type annotations everywhere they are cheap (`var t := game.tile_at(x, y)`, `-> void`). GDScript cannot infer a type from `Array[...]` element access or ternaries with mixed types; annotate explicitly in those cases (`var v: Vector2i = ...`) or the file will fail to parse.
- Tabs for indentation. One class per file. Section banners as `# ---- name` comments.
- Colours come from `Models.hex(0xRRGGBB)` and the palette constants in `UITheme`; reuse `Models.mat()`/`Models.glow()` so materials are cached.

## What not to do

- Do not put game rules in `main.gd`, `map_view_3d.gd` or `models.gd`. Do not reach into nodes from `game.gd` or `ai.gd`.
- Keep AI logic in `scripts/ai.gd`. It must only use public `Game` methods and the same information a player could have (respect `is_explored`).
- Do not add `.tscn` scenes for units, cities or tiles: everything is generated from code and synced incrementally. Do not add art or audio assets; extend `models.gd` and `sfx.gd` instead.
- Do not call `refresh()` from inside an animation step, and do not free unit nodes outside `_die()` / `_sync_units()`.
- Do not change tile geometry sizes casually: tiles are exactly 1 unit, caps are full width with no gaps (a faint seam line only), and units must always stand in the cleared centre/front of the tile.
- Do not rename or remove the debug hooks (`BP_SCREENSHOT`, `animations_enabled`); they are how the game is verified without a human.
- Do not use `set_anchors_preset()` for UI placement in `main.gd`; set `anchor_*`/`offset_*` explicitly (the preset recomputes offsets and breaks the layout).
- Do not edit anything under `goodlife/`.

## How to run and test

Godot is not on PATH on this machine. Use the app binary:

```
GODOT=~/Downloads/Godot.app/Contents/MacOS/Godot
```

- **Play:** `$GODOT --path .` (or open the folder in the Godot editor and press F5). `F11` toggles fullscreen.
- **After adding a new `class_name` script:** `$GODOT --headless --path . --import` to refresh the class cache, otherwise you get "Could not find type" parse errors.
- **Engine test (fast, headless):** `$GODOT --headless --path . --script tests/smoke.gd` plays three AI-vs-AI games and asserts unit/tile consistency. Run it after any change to `game.gd`, `ai.gd`, `map_gen.gd` or `defs.gd`. Same seeds give identical results, so a changed result means behaviour changed.
- **Visual check (no human needed):** `BP_SCREENSHOT=/tmp/shot $GODOT --path . --windowed --resolution 1440x900` auto-plays 8 turns and saves `shot_map.png`, `shot_tech.png`, `shot_levelup.png`, `shot_close.png`, `shot_units.png` (one of each unit type), `shot_archer_draw.png`/`shot_archer_loose.png`, `shot_anim.png` (mid-replay) and `shot_after.png`, then quits. It prints a picking self-test and star-counter reconciliation. macOS has no `timeout`; run it in the background and `kill` after ~90 s if it hangs.
- There is no unit-test framework; keep `tests/smoke.gd` green and look at the screenshots.
