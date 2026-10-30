# Wind Map Tier 3 Model Kit: Monkey Garden (`tier_3_monkey_garden`)

Handoff spec for the person or AI building the models. **Read all of it before modeling.** Also read `docs/art_style_guide.md` (project-wide rules, mandatory; written in Vietnamese).

## 1. Context

- Game: a fox adventure, 3D top-down 3/4 view, camera high and far (the character is ~7% of screen height). Godot 4.7.2, **GL Compatibility** renderer.
- The Wind map has 3 tiers. Tiers 1 and 2 are the Wind Palace (grey stone, cool blue). **Tier 3 is the palace's royal garden, overrun by a monkey tribe and turned into their lair.**
- Tier 3 enemies: monkey grunts (1.8 m tall) fighting in packs; mini-boss is the monkey chieftain (2.35 m tall).
- Target feeling: **"beautiful but chaotic"**. It must still read as a palace garden (stone walls, pavilion, bridge), but wrecked: trees growing through the paving, dirty ground, piles of stolen loot, palace banners torn into hammocks.
- This kit is **entirely new**; do not reuse models from `assets/models/wind_palace_v1`. You may open those models to match detail level and scale.

### References (look before modeling)

- Death's Door, *Estate of the Urn Witch*: small gardens linked in a loop around a central area.
- Zelda: Majora's Mask, *Deku Palace* (Outer / Inner Palace Garden): a garden belonging to a palace.
- Black Myth: Wukong, *Flower Fruit Mountain / Water Curtain Cave*: a monkey lair.
- Find the images yourself and note in the report which images were used for which model. **Do not copy** another game's assets.

## 2. Level design rules that affect the models

- **The player cannot jump.** Height changes only via stairs or ramps. No step higher than walkable, no gaps that need jumping.
- **No pits or chasms** to fall into. Streams and ponds are **dry beds** with stone rims.
- **Map borders are visible walls or fences.** Never use bushes as borders (players will think they can walk through).
- Monkeys can stand on pavilion roofs and large tree branches. Those surfaces must be **flat and wide enough for a 0.4 m-radius capsule**.
- Paths at least **2 m** wide; doorways at least **2.5 m** wide (the chieftain must fit).

## 3. Folders and files

- GLBs: `assets/models/map_wind/tier_3_monkey_garden/` (new folder; tiers 1 and 2 will be moved into `map_wind/` later — **do not touch them**).
- Inside the kit, at most **6 subfolders**: `ground/`, `walls/`, `structures/`, `plants/`, `monkey_props/`, `interactive/`. Each folder also holds at most 6 groups; if more, add another subfolder level.
- Shared files at the kit root: `README.md`, `manifest.json`, `garden_vertex_color.tres`, `garden_import.gd`.
- `.blend` source: `C:/Code/UITxVNG/Foxy_Art_Source/tier_3_monkey_garden/` (**outside the project**).
- QA images and helper scripts outside the project, e.g. `C:/Code/UITxVNG/output/tier_3_monkey_garden/`.
- `snake_case` filenames, include the size for modules, e.g. `wall_garden_4m.glb`.

## 4. Technical rules (summary; details in `art_style_guide.md`)

- 1 unit = 1 m, Y up, front faces **+Z** in Godot, pivot at **bottom center** (y = 0).
- Modules snap to a **2 m grid** (floors 2 m and 4 m, walls 4 m).
- Put the floor's walkable top surface at **y = 0** inside the model, so no height offset is needed when placing. The old palace kit got this wrong: floors were 0.32 m thick and the root had to be lowered.
- Vertex colors only, **no textures**. One shared material, plus at most one emissive material for interactive parts.
- Write `garden_import.gd` (post-import) to assign the shared material, like `assets/models/wind_palace_v1/palace_import.gd`. Verify in Godot that vertex colors render correctly.
- Moving or glowing parts (door leaves, chest lid, rustling leaves, swinging vines) are separate meshes with clear names, pivot at the rotation axis.
- No embedded cameras, lights, textures or default Cube.
- No flipped normals (the old kit had this bug, causing dark streaks). Check with Face Orientation in Blender.

## 5. Palette (starting proposal, must be measured)

Chosen tone: **warm earthy brown**, trampled ground. Moss only as accents at wall bases and hidden corners.

| Part | Proposed color |
|---|---|
| Ground / dirt floor | #5E4E3C |
| Broken floor stone | #6B6258 |
| Old stone wall | #4E4A46 |
| Moss (accent) | #4F5E3A |
| Wood, bamboo | #5A4630 |
| Leaves | #3F5A3A, highlight #5C7A48 |
| Tree trunk | #4A3B2E |
| Torn banner cloth (old palace banners) | #7FA7A8, faded, not emissive |
| Fruit, bananas (small color accents) | #C9A640 |
| Interactive (emissive) | #3FE0D0, interactive objects only, same as the palace kit |

**Brightness constraints (must be measured):**
- Take a screenshot in Godot at the game camera angle, with lighting. Average **floor** luminance (`Color.get_luminance()` on the image) must be **0.25–0.30**. The tier 2 floor is currently about 0.50.
- Walls at least 0.05 darker than the floor, to separate the walkable surface from the borders.
- The fox (orange), the monkeys and the player's ivory-white sword slash must stand out clearly on the floor. Also take grayscale shots to check.
- No orange or deep red on props (clashes with the fox and with danger cues).
- If the measurement fails, adjust the colors and record the final ones in the README. **Never report a pass without measuring.**

## 6. Model list

Triangle counts are hard caps; aim below them. "Repeated" means it will be scattered in bulk with MultiMesh and must be very light.

### 6.1 `ground/`

| File | Size (m) | Triangles | Notes |
|---|---|---|---|
| `floor_dirt_2m` / `floor_dirt_4m` | 2×2 / 4×4 | ≤ 60 / ≤ 120 | Packed dirt, slight undulation, flat walkable surface |
| `floor_stone_broken_2m` / `_4m` | 2×2 / 4×4 | ≤ 150 / ≤ 300 | Broken palace paving with dirt showing between slabs; flat walkable surface (bumps ≤ 2 cm) |
| `path_edge_2m` | 2 long | ≤ 80 | Broken-stone path edging |
| `moss_patch_s` / `_m` | 0.6 / 1.5 | ≤ 30 / ≤ 60 | Flat moss patch on the floor, repeated |
| `stair_mossy_2m` | 2 wide, 1 high, 2 deep | ≤ 300 | Mossy stone stairs, each step ≤ 0.25 high |
| `ramp_dirt_4m` | 2 wide, 4 long, 1 high | ≤ 150 | Dirt ramp, slope ≤ 30° |
| `dry_streambed_4m` | 4 long, 2 wide | ≤ 250 | Dry stream bed with stone rim, depth ≤ 0.2 (walkable, not a pit) |

### 6.2 `walls/`

| File | Size (m) | Triangles | Notes |
|---|---|---|---|
| `wall_garden_4m` | 4 long, 3 high, 0.6 thick | ≤ 300 | Old garden stone wall, cracked, moss at the base |
| `wall_garden_corner` | 0.6×0.6×3 | ≤ 150 | Corner post |
| `wall_garden_arch_4m` | 4 long, 3.5 high | ≤ 400 | Arched opening, clear width ≥ 2.5 m, height ≥ 2.8 m |
| `wall_garden_broken_4m` | 4 long, 1.5–3 high | ≤ 350 | Partly collapsed wall, **still blocks the player** (lowest part ≥ 1.2 m) |
| `fence_bamboo_2m` | 2 long, 1.6 high | ≤ 150 | Bamboo fence built by monkeys, tied with rope |
| `vine_wall_cover_4m` | 4×3 | ≤ 200 | Vines covering a wall face, separate mesh, placed flush to the wall |

### 6.3 `structures/`

| File | Size (m) | Triangles | Notes |
|---|---|---|---|
| `garden_gate` | 4 wide, 4 high | ≤ 800 | Palace-style garden gate, door leaves are separate meshes (hinge pivot) |
| `pillar_vine_4m` | 0.8×0.8×4 | ≤ 250 | Stone pillar wrapped in vines |
| `pavilion_small` | 4×4, 4 high | ≤ 1,500 | Small curved-roof pavilion; roof top flat enough for monkeys to stand; 4 posts, no walls |
| `bridge_arched_4m` | 4 long, 2 wide | ≤ 500 | Arched stone bridge over a dry stream, with railings; deck reachable by slope |
| `planter_stone_2m` | 2×2, 0.6 high | ≤ 150 | Stone-rimmed flower bed |
| `pond_dry_4m` | 4×4 | ≤ 300 | Dry pond with stone rim, depth ≤ 0.2 |

### 6.4 `plants/`

| File | Size (m) | Triangles | Notes |
|---|---|---|---|
| `tree_ancient` | canopy ~10, height ~9 | ≤ 4,000 | Ancient centerpiece tree for the boss room. The canopy **must not hide the fight area** from the camera (high canopy, open center). 2–3 large flat branches for monkeys to stand on |
| `tree_garden` | canopy ~4, height ~5 | ≤ 800 | Medium garden tree; canopy is a separate mesh (so it can fade when it covers the player) |
| `tree_young` | ~2.5 high | ≤ 250 | Young tree |
| `roots_through_floor` | 3×2 | ≤ 300 | Roots breaking through the paving, ≤ 0.3 high (does not block a path) |
| `bush_broad_s` / `_m` | 0.8 / 1.6 | ≤ 80 / ≤ 160 | Broad-leaf bush, repeated |
| `vine_hanging` | 2–3 long | ≤ 60 | Vine hanging from a roof or arch, separate mesh (can sway) |

### 6.5 `monkey_props/`

| File | Size (m) | Triangles | Notes |
|---|---|---|---|
| `loot_pile` | 2×2, 1 high | ≤ 600 | Pile of stolen goods: palace urns, cloth, fruit |
| `banana_bunch` / `fruit_peels` | 0.3 / 0.5 | ≤ 60 / ≤ 40 | Repeated, scattered on the floor |
| `banner_hammock` | 3 long | ≤ 200 | Hammock made from a torn palace banner, tied between two posts or trees |
| `nest_branch` | 1.2 | ≤ 200 | Monkey nest placed on a branch |
| `chieftain_throne` | 3×2.5, 3 high | ≤ 1,500 | Chieftain's throne cobbled from scavenged items (broken palace chair, banners, stones, bones). Fits a seated 2.35 m monkey |
| `territory_totem` | 0.6, 2.2 high | ≤ 300 | Stake with a mask or animal skull marking territory. **No gore** |

### 6.6 `interactive/` (visuals only)

Mechanics are not decided yet; build the visuals only, with moving parts as separate meshes.

| File | Size (m) | Triangles | Notes |
|---|---|---|---|
| `garden_door_locked` | 3 wide, 3.5 high | ≤ 800 | Locked door, lock glows #3FE0D0 (secondary material) |
| `key_pedestal_garden` | 0.8×0.8×1.1 | ≤ 300 | Key pedestal |
| `chest_garden` | 1.2×0.8×0.8 | ≤ 400 | Chest, lid is a separate mesh (hinge pivot) |

## 7. Order of work

1. Write `garden_import.gd` and `garden_vertex_color.tres`. Build **ground + walls** first. Assemble a 12×12 m test corner in a separate Godot scene under `tests/`, take screenshots, and **measure floor luminance** (section 5). Continue only if it passes.
2. Then structures → plants → monkey_props → interactive.
3. After each group: export the GLBs, import them in Godot, and render color + grayscale contact sheets at the game camera angle.

## 8. Do not

- Modify, move or delete files of other kits (`wind_palace_v1`, `wind_kit`, ...), level scenes, builders or gameplay code.
- Edit `project.godot` or install addons.
- Commit to git.
- Fabricate: anything not measured is written as "not measured". Never report "passes" without viewing the image in Godot.

## 9. Handoff (the kit's README.md, written in Vietnamese)

- Actual model list, sizes measured from the GLBs, triangle counts (matching `manifest.json`).
- Final palette and measured floor luminance.
- QA images: color and grayscale contact sheets, the assembled test corner, a shot with the fox and a monkey next to the props for scale.
- Reference images used for each group.
- A list of open issues and anything not done.
