# Last Light enemies: the brain contract

Each enemy kind is a **brain**: `scripts/cast/enemies/<id>.gd`, which extends `enemy.gd`. The Run
(`scripts/game/run/run.gd`, the `game` object every brain talks to) hosts them through `scripts/game/run/enemies.gd`,
which creates, steps (at `enemy_tempo`), hits, kills and draws brains; `scripts/game/run/view.gd` paints them. The
director (`scripts/game/run/director.gd`) decides when they spawn and what light shards each kill drops. The Snuffer (`snuffer.gd`)
is the worked example. Art and numbers come from `art/cast/enemies/<id>/<id>.json`, which `enemy_kit.gd`
loads once per kind.

## Files
- You own `scripts/cast/enemies/<id>.gd`, any `<id>_*.gd` helpers (hazards too), `art/cast/enemies/<id>/` and
  your art script.
- Read but don't edit: `enemy.gd`, `enemy_kit.gd`, `hazard.gd`, `snuffer.gd`, `scripts/game/run/*.gd`,
  `scripts/cast/light_fx.gd`, `scripts/game/fx/settings_fx.gd`, `tests/enemy_*`. If you need something they don't
  offer, report it.

## Adding a kind
1. Export the art: `cd docs/art_concepts/lastlight && python3 cast/export_godot.py <id>`. Then re-import with
   the shared lock script (never run a second editor import alongside it).
2. Write `<id>.gd`: `extends "res://scripts/cast/enemies/enemy.gd"`. Once the file exists, the director
   spawns your kind on the timeline instead of Snuffers. Lab mode and the debug keys pick it up too.
3. Test it (commands at the end).

## Lifecycle (the game calls these; override what your kind needs)
On spawn the game sets `game`, `kit`, `id`, `kind`, `hp` (director `hp(id)`: ROSTER `hp`, x10 scale, growing with
the clock) and
`node`. It then calls `arrive(anchor, index, count)`, which sets `pos`, and then `setup()`.

| virtual | default | notes |
|---|---|---|
| `arrive(anchor, i, n)` | anchor; a pack scatters around it on walkable ground | `anchor` = `game.edge_point()`, a walkable point just outside the view. The sporecap (land near Wick) and magpie (view edge) choose their own. |
| `setup()` | `kit.pick_look()`, plays `spawn` | `node` already exists (set `node.material` here for a shader). Set `xp` or rescale `hp` here. |
| `step(dt)` | `advance(dt)` | Alive, every simulation step. `dt` = world seconds x `game.enemy_tempo` (DIFFICULTY sold: 1.15, 1.3). Not called during `hit_stop`. Move with `walk(step)` or set `pos`. Apply `push` yourself. |
| `step_dead(dt)` | plays the death, then `gone = true` | Remnant (killed). Not called during `hit_stop`. |
| `aimable()` | `not dead` | Auto-aim, the bell toll and the fireflies skip it when false (owl high, falling sporecap). |
| `centre()` | `pos` + frame_data `hit_centre`/`centre`, else JSON `centre`/`body_centre` | World px, mirrored with the sprite. Shots aim here; splash and stings measure to it. |
| `reach()` | `kit.hit_radius` | Body radius around `centre()`. |
| `shot_hits(p)` | `aimable()` and within `reach()+1` of `centre()` | The game first culls points more than 32 px sideways, 96 px above or 24 px below `pos`. |
| `blocks(from)` | false | `from` = where the attack came from: a shot's position 8 px back along its path, the toll's impact point, or the firefly dart's launch point. True = no damage, no flash, no impact and no toll; the shot ends (pierce too). |
| `on_block(at, from)` | nothing | Play your block and splash. `at` = the shot's position (for splash and stings: your edge toward `from`). |
| `hurt(dmg, push, from)` | flash 60 ms, `hit_stop` by damage tier (`HIT_STOP`), `push = push`, plays `hurt` | hp is already lower and it lives. `from` is `Vector2.INF` when unknown. |
| `die(push, from)` | `dead = true`, hit-stop, plays `death` | Already out of `enemies`; the kill's light shards are dropped (director ROSTER `shards`; `xp` is unused since beta v1). Becomes a remnant. |
| `touches(body, r)` | `aimable()` and the hit circle overlaps Wick's body circle | Contact damage (the owl's dive; the magpie returns false). |
| `flyer()` | false | True = drawn on the flyer layer above props and actors (magpie always, owl while high). |
| `solid()` | alive and not a flyer | Takes part in the walkers' crowd push (`game.separation`). |
| `draw_shadow(ci)` / `draw_body(ci)` / `draw_eyes(ci)` | the clip's `shadow` / `body` (or `flash`) / `eyes` layer at `pos` | See Drawing. |
| `is_flash_frame(f)` | frame_data `flashed: true` or `event: "hit"` | Baked flash frames are skipped once HIT FLASH is sold. Override if your hurt frame 0 is flashed but not marked (toad, sporecap, gloam, magpie). |
| `lab_check(stats)` | no failures | Your assertions for `tests/enemy_check.gd` (see Testing). |

Set `gone = true` to leave. An alive brain is then removed with no kill (the magpie's escape). A remnant is
dropped. Never touch `game.enemies` yourself.

## Animation helpers (enemy.gd)
- `play(name)` restarts a clip. `set_dir(d, mirrored)` switches the view now. `face(vel, dt)` picks
  side/front/back from velocity (side when |vx| > 0.7|vy|) and needs 150 ms of hold before turning. Call
  `play` before the first `set_dir`.
- `advance(dt)` returns true when the frame changes; then read `fd("event")`. Also: `frame()`, `frame_at(t)`,
  `done()`, `fd(key, default)` (the current frame_data).
- ANIMATIONS sold (`still()`): loops hold frame 0, one-shots show frame 0 until they end. A one-shot whose
  frame 0 is a flash frame (`is_flash_frame`) shows it for `FLASH_TIME` only (never once HIT FLASH is sold), then
  holds the first frame after it. `frame()` already
  applies this, and movement goes on.
- `kit.clip(anim, dir, look)` gives `{anim, dir, loop, size, anchor, frames, ms, total, data, tex{layer}}`.
  A missing view falls back to front, side, any, then back. Any view name works, e.g. the toad's
  `"side-front34"`. Layers with "shadow" in the name use `kit.shadow_size`/`shadow_anchor`; every other layer
  uses the animation's frame and anchor. Use `kit.behaviour`, `kit.tells` and `kit.data` for your numbers.

## Drawing (the game picks the layer; you draw in world px)
- **Shadows**: `draw_shadow` draws under the Sort layer through `scripts/cast/shade.gdshader`. Any colour
  works; the shader shades the ground under it.
- **Body**: `draw_body` draws into your `node` in the island's y-sorted Sort layer (shared with props and Wick).
  The node sits at `pos.round()`, so `pos` is the sort point. Flyers draw on the flyer layer instead (above
  the props' Over layer). Hazards draw there too.
- **Eyes**: `draw_eyes` runs only in the PIXELS finale, on the layer above the screen effects (with the
  lantern), so eyes stay over the dead pixels. At DISPLAY: OFF they blink out within 0.6 s.
- `draw_layer(ci, layer, at = pos, f = current)` draws one sheet layer with the anchor on `at`. A mirrored
  side view (any view except front, back and any) flips about the anchor. A mirrored shadow uses the clip's
  unflipped `shadow_mirror` or `shadow_left` sheet when there is one. Extra layers (specks, stars) are just
  more `draw_layer` calls.
- Hit flash: `flash > 0` swaps in the `flash` layer unless HIT FLASH is sold (`game.lv("hit_flash") > 0`).
- Your death replaces the light's generic dissolve (it no longer plays for these kinds); the light's hit
  impact still plays. `game.light_overlay("death_large", pos)` plays a named light overlay (it follows the
  light's own rules: none when PARTICLES is sold or in the finale).

## Game API (call on `game` = the Run, `scripts/game/run/run.gd`)
`wick_feet()`, `wick_body()` (contact circle centre, radius player.gd `BODY_RADIUS` = 3.5), `lantern()` (the glass),
`glow_tier()` (0..2), `damage_tier()` (0..3), `lv(id)` (times a setting was sold; `"pixels"` = % dead),
`clock()` (enemy clock in s), `still()`, `tick()` (the 2 s world loop at 12 fps, 0..23), `finale()`,
`display_off()`, `view_rect()`, `edge_point()`, `open(p, mask = 1)` (on the island and not inside a collider on
`mask`: 1 walk, 2 shots), `shot_open(p)`, `walk(e, step, fly)` (via `walk(step, fly)` on the brain),
`separation(e)`, `light_pools()` (x, y, radius per pool; empty once BRIGHTNESS is sold), `add_hazard(h)`,
`enemy_sound(name)`, `free_level_up()`, `light_overlay(sheet, pos)`, `spawn(id, anchor, index, count)`,
`alive(id)`, `stat(key, n)`, `hurt_enemy(e, dmg, push, from)`. Also readable: `world_speed`, `enemy_tempo`, `run_time`,
`enemies`, `remnants`, `hazards`, `player_pos`, `immortal`, `director`, `view` (e.g. `view.pools`), `level`.
Everything else on the Run (phases, signals, sales) is for the game's own modules, not for brains.

## Hazards (`hazard.gd`)
Extend it in `<id>_*.gd` and hand an instance to `game.add_hazard(h)`. It outlives its owner. Fields: `pos`,
`vel`, `radius`, `life`, `harmful`, `blocked_by_cover`, `gone`, `age`. The game calls `step(dt)` (default: fly
and age; `expire()` at the end of `life`). It calls `on_blocked()` inside cover or a landmark (shot layer 2),
`on_hit_wick()` on contact (the game hurts Wick) and the draws `draw_shadow`/`draw`/`draw_eyes`. Keep a hazard
alive with `harmful = false` to play its pop.

## Director (`scripts/game/run/director.gd`)
`ROSTER` holds per-kind `from`, `share`, `ramp`, `cap`, `pack`, `lab_every`, `hp`, `size` and `shards` (the light
shards a kill drops over time; GAME_DESIGN 7.1). `RATE` is the steady spawn curve over the run (slow start for a first sale at 20-30 s, a dip while the newcomers arrive, a climb to the
finale); `FINALE_RATE` on top in the finale. `EVENTS` holds the scripted debuts: owl 0:40, magpie 1:10 then every
50-60 s (cap 1, none in the finale), toad 1:30, sporecap 2:15 then every 40-50 s, gloam pack of 4 at 3:00. Each
debut has a `quiet` lull (no steady spawns a few seconds before and after) and arrives on the clear side of the
view, so the newcomer reads alone. `FORMATIONS` from 3:30, FORMATION_GAP 22 s apart in turn: Snuffer ring, owl
parliament (4), toad line (3), spore garden (3), Gloam pack (5); each is announced 2.5 s ahead by the
`formation` sound and a lull. Events and formations may go past caps and `ENEMY_CAP` 130. A kind without a brain
becomes Snuffers. `tests/run_check.tscn` plays the whole run and prints the timeline.

## Sounds
Call `game.enemy_sound("owl_hoot")` at your tell moments, with the names from your JSON `tells`. Each name is a
file `audio/sfx/<name>.ogg` with an `SFX_DB` entry in `scripts/game/fx/settings_fx.gd`; unknown names do nothing,
and SOUND sold mutes them. The game thins crowds (`scripts/game/run/enemies.gd` `SOUND_GAP`/`SOUND_GAPS` per name,
`SOUND_VOICES` per `SOUND_WINDOW`, except `SOUND_TELLS`), so call it freely.

## Testing (GODOT=/Applications/Godot.app/Contents/MacOS/Godot, from the project folder)
- Check: `"$GODOT" --headless --path . --fixed-fps 60 res://tests/enemy_check.tscn -- lab=<id> secs=60`. Expect
  `ENEMY CHECK PASS <id>` and exit 0. Options: `at=<s>`, `sell=particles,animations`, `finale`, `mortal`,
  `crowd=<n>` (stress run), `seed=<n>` (runs are seeded, default 1, so a run repeats exactly; `seed=random`
  samples another one). Generic assertions: spawned, killed and deaths finished; walkers stay on walkable
  ground. Stats keys: `spawned_<id>`, `killed_<id>`, `remnants_done_<id>`, `left_<id>`, `hits`, `blocks`,
  `hazards`, `hazards_blocked`, `wick_hurt_<id>`, `wick_hurt_hazard`, `sold_<setting>`, and anything you
  `game.stat()`.
- Render (Movie Maker, 13 s; frames are 320x180 PNGs):
  `"$GODOT" --path . --resolution 640x360 --write-movie <dir>/f.png --fixed-fps 30 --quit-after 390 res://tests/enemy_render.tscn -- lab=<id>`.
  At 0 s and 7 s a ring of 8 appears (the second ring can't die), ANIMATIONS is sold from 6 to 7.5 s, the
  finale starts at 8 s and DISPLAY: OFF comes at about 11.5 s. Level-up menus close at once; `trace` prints the
  state twice a second. The window stays on top: macOS stops drawing a covered window and Movie Maker then repeats
  the last frame, which looks like a frozen game.
- Play: `"$GODOT" --path . -- lab=<id>` (the main scene; a debug run that skips the title, add `at=180` to start
  later). In debug builds, keys 1-6 drop a snuffer, owl, toad, sporecap, gloam or magpie near Wick, and 0
  drops one of each.

## Decisions already made
- Owl: it can't be shot while high (altitude >= 16 px), only in the dive and the recover tumble. Dive 0.5 s,
  about 120 px including a 40 px overshoot.
- Sporecap: it fires its first ring right after sprouting.
- Toad: turn rate 85 deg/s (one constant). The ±55° block covers pierce, splash and stings.
- Gloam: a hit lights the whole shape for one frame even in the dark, but selling HIT FLASH removes it. Only a
  dash bites (a crouched Gloam is harmless), and one that bit spends its next dash bounding away (`FLEE_TURN`).
- Toad: only its body (sides and back) hurts on contact; the dome is a shield that pushes Wick back out, no damage.
- Magpie: the 9 s escape counts world time (`game.clock()`), so hit-stops don't stretch it.
  `light_pools()` gives the reveal pools, `lantern()` + `glow_tier()` the lantern's.
- Magpie: contact damage 0. Kill = `game.free_level_up()` (the star flies to `game.lantern()` in your remnant).
  Leave with `gone = true`.
- Flyer shadows stay as drawn (under the bird). Every death replaces the light's dissolve.
