# AGENTS.md: Godot RTS Advanced Lite

## What this is
Godot RTS Advanced Lite is a free, MIT-licensed **Godot 4 3D real-time strategy (RTS) starter kit / template** written in strictly typed GDScript for Godot 4.7 (tested on 4.7.2). It provides decoupled, headless-testable RTS systems plus a primitive-shape demo. The paid Pro edition (€19, commercial EULA) has the same core API plus more systems and a full skirmish demo: https://huginhelm.itch.io/godot-rts-advanced
Website: https://openclawaimac.github.io/godot-rts-advanced/

## Structure
- `addons/rts_advanced/rts_teams.gd` – RTSTeams: ally/enemy/neutral relations, team colours
- `addons/rts_advanced/rts_selection.gd`, `rts_selection_box.gd` – RTSSelection / RTSSelectionBox: box/click/shift/ctrl selection, control groups, type counts
- `addons/rts_advanced/rts_orders.gd` – RTSOrders: move in formation, attack, stop
- `addons/rts_advanced/rts_formation.gd` – RTSFormation: box/line slots, crossing-free assignment
- `addons/rts_advanced/rts_grid_nav.gd` – RTSGridNav: 8-way grid A*, obstacles, nearest open cell
- `addons/rts_advanced/rts_separation.gd` – RTSSeparation: unit spacing while moving
- `addons/rts_advanced/rts_unit.gd` – RTSUnit: path following, health, attack range/cooldown, chase
- `addons/rts_advanced/rts_production.gd` – RTSProductionQueue: queue, pay on queue, refund on cancel, rally point
- `addons/rts_advanced/rts_economy.gd`, `rts_resource_node.gd` – RTSEconomy / RTSResourceNode: credits, capturable income points
- `addons/rts_advanced/rts_camera.gd` – RTSCamera: pan/zoom/bounds, screen-to-ground picking
- `addons/rts_advanced/rts_bindings.gd` – RTSBindings: default actions, rebinding with conflict check, save/load
- `addons/rts_advanced/rts_loc.gd` – RTSLoc: t(key, params), live language switch, missing-key report
- `examples/` – demo.tscn / demo.gd (primitive-shape demo wiring all systems)
- `localization/` – demo.csv (en/fr)
- `tests/` – strict headless suite (run_tests.gd, harness.gd, expected.json)
- `tools/` – run_tests.sh, selftest_harness.sh, make_release.sh

## Run the tests
```bash
godot --headless --path . --import   # once, after clone or after adding a class_name
bash tools/run_tests.sh /path/to/godot   # or set GODOT=...; must print "RESULT: PASS 114 checks" and exit 0
```
The runner fails on non-zero exit, any `SCRIPT ERROR`, a missing `RESULT: PASS` line, or a section/check count that differs from `tests/expected.json`.

## How to extend
- Systems are plain `RefCounted`/`Node` classes: create them in code and connect their signals; `examples/demo.gd` shows the wiring.
- New unit types: set `RTSUnit.unit_type` and stats; selection counts, control groups and production queues work per type.
- Read each class's `##` doc comments; `tests/run_tests.gd` has a working example of every public function.
- Add tests for new behaviour: a section in `tests/run_tests.gd` (`await H.section("test_x", test_x)`), then update `tests/expected.json`.

## Rules
- Godot 4.7.2, typed GDScript (untyped declarations are errors). Run `godot --headless --path . --import` after adding a class_name.
- Tests: `bash tools/run_tests.sh /path/to/godot` must print `RESULT: PASS`.
- Keep the core API identical to the Pro edition.

## Lite vs Pro
Lite = free, MIT, 114 tests, core systems + primitive demo. Pro = €19, commercial per-seat EULA, 356 tests, adds terrain, cliff-aware pathfinding, cover/armour/suppression combat, production manager and squads, harvesting, construction with power, fog of war, AI opponent, save/load, minimap and a full 3D skirmish demo, same core API. See README.md "Lite vs Pro" or https://openclawaimac.github.io/godot-rts-advanced/. Get Pro: https://huginhelm.itch.io/godot-rts-advanced
