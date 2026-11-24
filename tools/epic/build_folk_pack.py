#!/usr/bin/env python3
"""Build and validate luxel/data/packs/folk.json (interactables, 32 panes, 80 moths, quests, 10 folk, strings).

Validates every string against LxStrings rules:
  - uppercase 3x5 charset: A-Z 0-9 ! - : x / . + = space %
  - max 45 characters per line (even when %d/%s expand to 999)
"""
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT_PATH = ROOT / "luxel" / "data" / "packs" / "folk.json"
ALLOWED = set("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!-:x/.+= %")

PANES_DEF = [
    # (id, island, source, lead, tint, name, desc)
    ("bell_clapper", 1, "dungeon", 2, "gold", "CLAPPER GLASS", "RECALL RINGS 36PX CHIME - SHORTER THROW"),
    ("vesper_chime", 1, "trial", 1, "apricot", "VESPER PANE", "EVERY 4TH BOLT PIERCES - SLOWER FIRE"),
    ("toll_echo", 1, "quest", 2, "gold", "TOLL ECHO", "PERFECT DODGE LEAVES A RINGING DECOY"),
    ("belfry_weight", 1, "secret", 3, "coral", "BELFRY WEIGHT", "HEAVY RECOIL KICK - CLOSE BOLTS BLAST"),

    ("rip_tide", 2, "dungeon", 2, "sky", "RIP TIDE", "ZIP DRAGS NEARBY FOES - SHORTER HANG"),
    ("sea_glass", 2, "trial", 1, "ice", "SEA GLASS", "BOLTS BOUNCE +1 TIME - SHORTER REACH"),
    ("harbor_wake", 2, "quest", 2, "sky", "HARBOR WAKE", "DASH DROPS SLOWING FOAM - LONGER CD"),
    ("anchor_lead", 2, "secret", 3, "blue", "ANCHOR LEAD", "HEAVY LONG HANG - SLOWER WHEN OUT"),

    ("ember_seed", 3, "dungeon", 2, "lime", "EMBER SEED", "BOLT HITS DROP EMBER POOLS - SLOWER"),
    ("briar_thorn", 3, "trial", 1, "jade", "BRIAR THORN", "HURT BURSTS THORN RING - LESS EMBER"),
    ("vine_snare", 3, "quest", 2, "jade", "VINE SNARE", "THROW ROOTS FOES ON LAND - SLOWER"),
    ("canopy_dew", 3, "secret", 3, "lime", "CANOPY DEW", "3 ROOM KILLS HEAL HALF - SLOWER FIRE"),

    ("hourglass_sand", 4, "dungeon", 2, "gold", "HOURGLASS SAND", "PERFECT DODGE ARMS LANCE - LONGER CD"),
    ("petal_mirror", 4, "trial", 1, "rose", "PETAL DECOY", "DASH LEAVES 2S PETAL DECOY - LONGER CD"),
    ("dusk_dew", 4, "quest", 2, "ice", "DUSK CLOCK", "FIRST 4S IN ROOM: x2 EMBER THEN LESS"),
    ("rain_prism", 4, "secret", 3, "ice", "RAIN PRISM", "RECALL RAINS 4 SPARKS - SLOWER RETURN"),

    ("orbit_shard", 5, "dungeon", 2, "gold", "ORBIT SHARD", "KILLS SPAWN ORBITING STAR - DIMMER"),
    ("comet_tail", 5, "trial", 1, "sky", "COMET TAIL", "FAR BOLTS FLARE HARD - WEAKER CLOSE"),
    ("zenith_lens", 5, "quest", 2, "cream", "ZENITH LENS", "FULL HEARTS: 3RD BOLT IS A LANCE"),
    ("null_well", 5, "secret", 3, "deep", "NULL WELL", "HUNG LANTERN PULLS MOTHS - DIMMER"),

    ("cinder_blast", 6, "dungeon", 2, "coral", "CINDER BLAST", "RECALL DETONATES HUNG LANTERN"),
    ("slag_coat", 6, "trial", 2, "apricot", "SLAG COAT", "ROOM ENTRY GRANTS ASH WARD - SLOWER"),
    ("bellows_vent", 6, "quest", 1, "coral", "BELLOWS VENT", "DASH BLASTS EMBER CONE - MORE RECOIL"),
    ("anvil_strike", 6, "secret", 3, "apricot", "ANVIL STRIKE", "ZIP CRACKS SHIELDS WIDE - LONGER CD"),

    ("silver_twin", 7, "dungeon", 3, "ice", "SILVER TWIN", "THROW FIRES BACKWARD SILVER BOLT"),
    ("moon_phase", 7, "trial", 1, "ice", "MOON PHASE", "BOLTS ALTERNATE FAR ICE AND CLOSE GOLD"),
    ("glass_step", 7, "quest", 2, "sky", "GLASS STEP", "DASH PAST FOE HALVES CD - DIMMER"),
    ("mirror_ward", 7, "secret", 2, "ice", "MIRROR WARD", "HURT BLINKS TO HUNG LANTERN"),

    ("toll_wick", 8, "dungeon", 1, "rose", "TOLL WICK", "LOW HEARTS PIERCE HARD - DIMMER LIGHT"),
    ("hush_glass", 8, "trial", 2, "plum", "HUSH GLASS", "DIMMER LANTERN - FASTER STEP AND DASH"),
    ("dawn_spark", 8, "quest", 3, "gold", "DAWN SPARK", "KILLS FLASH LIGHT + EMBER - SHORT BOLT"),
    ("last_glass", 8, "secret", 3, "rose", "LAST GLASS", "EMPTY EMBER BOOSTS BOLTS - SLOW FILL"),
]

STRINGS = {
    # Pause & UI chrome
    "PAUSE_JOURNAL": "JOURNAL",
    "PAUSE_PANES": "PANES",
    "FMT_RATIO": "%d/%d",
    # Panes menu
    "PANES_TITLE": "LANTERN PANES",
    "PANES_VIEW_ONLY": "VIEW",
    "PANES_LEAD_FMT": "LEAD %d/%d",
    "PANES_OWNED_FMT": "%d/%d",
    "PANES_TAB_ALL": "ALL",
    "PANES_ISL_COUNT_FMT": "ISL %d: %d/%d",
    "PANES_HINT_EDIT": "ENTER/DRAG: FIT  Q/E: ISLE  ESC: BACK",
    "PANES_HINT_VIEW": "VIEW ONLY - FIT AT REST SHRINES",
    "PANES_READONLY_TIP": "FIT PANES AT A REST SHRINE OR HUB",
    "PANE_UNKNOWN_NAME": "UNFOUND GLASS",
    "PANE_SRC_FMT": "ISLAND %d - %s",
    "PANE_SRC_DUNGEON": "DUNGEON",
    "PANE_SRC_TRIAL": "TRIAL",
    "PANE_SRC_QUEST": "QUEST",
    "PANE_SRC_SECRET": "SECRET",
    "PANE_COST_FMT": "LEAD %d  ISL %d",
    "PANE_EQUIPPED": "PANE FITTED",
    "PANE_REMOVED": "PANE REMOVED",
    "PANE_FOUND": "STAINED PANE FOUND",
    "PANE_ERR_UNOWNED": "NOT YET FOUND",
    "PANE_ERR_EQUIPPED": "ALREADY FITTED",
    "PANE_ERR_SLOTS": "NO OPEN GLASS SLOT",
    "PANE_ERR_LEAD": "NOT ENOUGH LEAD",
    # Journal
    "JOURNAL_TITLE": "JOURNAL",
    "JOURNAL_TAB_QUESTS": "QUESTS",
    "JOURNAL_TAB_MOTHS": "MOTHS",
    "JOURNAL_TAB_BESTIARY": "FOES",
    "JOURNAL_TAB_TOYS": "TOYS",
    "JOURNAL_NO_QUESTS": "NO FOLK ERRANDS YET",
    "JOURNAL_Q_DONE": "DONE",
    "JOURNAL_Q_OPEN": "OPEN",
    "JOURNAL_Q_NEW": "NEW",
    "JOURNAL_MOTHS_FMT": "LOST MOTHS: %d/%d",
    "JOURNAL_TIERS": "TIERS:",
    "JOURNAL_UNSEEN": "UNSEEN",
    "JOURNAL_SD_FMT": "S:%d D:%d",
    "JOURNAL_HINT": "Q/E: PAGE   ARROWS: BROWSE   ESC: BACK",
    # Folk, quests, moths
    "PROMPT_TALK": "LISTEN",
    "PROMPT_TALK_NEXT": "NEXT",
    "PROMPT_PICKUP": "TAKE",
    "PROMPT_TAKE_PANE": "TAKE PANE",
    "FOLK_RESCUED": "A FRIEND FOUND THE WAY TO WICK HOUSE.",
    "MOTH_CAUGHT": "A LOST MOTH DRAWS TO THE LANTERN.",
    "MOTH_REWARD_CLAIMED": "THE MOTH LANTERN GRANTS A GIFT.",
    "MOTH_LANTERN_INFO": "BRING LOST MOTHS TO GROW THIS LIGHT.",
    "QUEST_TIMER_EXPIRED": "THE DUSK BELL RAN OUT. TRY AGAIN.",
    # Moth tier cues
    "MOTH_TIER_5": "5 MOTHS: EXTRA LEAD GAINED.",
    "MOTH_TIER_10": "10 MOTHS: EMBER PIECE GAINED.",
    "MOTH_TIER_20": "20 MOTHS: 4TH GLASS SLOT OPENED.",
    "MOTH_TIER_35": "35 MOTHS: ICE FLAME UNLOCKED.",
    "MOTH_TIER_50": "50 MOTHS: 5TH GLASS SLOT OPENED.",
    "MOTH_TIER_65": "65 MOTHS: EMBER PIECE GAINED.",
    "MOTH_TIER_80": "80 MOTHS: THE FIRST DARK STIRS.",
    # Toys catalog short labels
    "TOY_BLOCK": "PUSH BLOCK",
    "TOY_PLATE": "PRESS PLATE",
    "TOY_BRAZIER": "TIMED FLAME",
    "TOY_CRYSTAL": "CRYSTAL SWAP",
    "TOY_PLATFORM": "MOVER RAFT",
    "TOY_CONVEYOR": "CONVEYOR",
    "TOY_WIND": "WIND LANE",
    "TOY_GRAVITY": "STAR WELL",
    "TOY_PLANT": "SEED LIGHT",
    "TOY_SHADOW": "SHADOW GATE",
    "TOY_SCALE": "TWIN SCALE",
    "TOY_RING": "PULL RING",
    "TOY_ORB": "CARRY ORB",
    "TOY_HOOK": "LAMP HOOK",
    "TOY_ROSE": "ECHO ROSE",
    "TOY_SKIFF": "HARBOR SKIFF",
}

panes_json = {}
for idx, (pid, isl, src, lead, tint, pname, pdesc) in enumerate(PANES_DEF):
    nk = f"PANE_{pid.upper()}_NAME"
    dk = f"PANE_{pid.upper()}_DESC"
    STRINGS[nk] = pname
    STRINGS[dk] = pdesc
    panes_json[pid] = {
        "id": pid,
        "island": isl,
        "source": src,
        "lead": lead,
        "tint": tint,
        "icon_index": idx,
        "name_key": nk,
        "desc_key": dk,
        "script": f"res://luxel/player/panes/p_{pid}.gd",
    }

# Validate every string strictly!
for k, v in STRINGS.items():
    exp = v.replace("%d", "999").replace("%s", "999")
    if len(exp) > 45:
        raise ValueError(f"String {k} too long ({len(exp)}): {exp}")
    for ch in exp:
        if ch not in ALLOWED:
            raise ValueError(f"String {k} has invalid char {ch!r}: {v}")

moths_json = []
for isl in range(1, 9):
    for n in range(1, 11):
        moths_json.append({
            "id": f"moth_{isl}_{n:02d}",
            "island": isl,
            "index": (isl - 1) * 10 + n,
        })

moth_tiers = [
    {"count": 5, "cue_key": "MOTH_TIER_5", "reward": {"kind": "lead", "amount": 1}},
    {"count": 10, "cue_key": "MOTH_TIER_10", "reward": {"kind": "ember_piece", "amount": 1}},
    {"count": 20, "cue_key": "MOTH_TIER_20", "reward": {"kind": "slot", "amount": 1}},
    {"count": 35, "cue_key": "MOTH_TIER_35", "reward": {"kind": "flame", "value": "ice", "amount": 1}},
    {"count": 50, "cue_key": "MOTH_TIER_50", "reward": {"kind": "slot", "amount": 1}},
    {"count": 65, "cue_key": "MOTH_TIER_65", "reward": {"kind": "ember_piece", "amount": 1}},
    {"count": 80, "cue_key": "MOTH_TIER_80", "reward": {"kind": "flame", "value": "gold", "amount": 1}},
]

quests_json = [
    {
        "id": "q_bell_clapper",
        "island": 1,
        "kind": "carry_back",
        "folk": "bell_snail",
        "icon": "quest_carry",
        "rescue_folk": "bell_snail",
        "steps": [
            {"icons": ["bell", "question", "arrow_e", "quest_carry"], "need": "quest:item:brass_clapper", "consume_item": "brass_clapper", "flag": "quest:q_bell_clapper:s0"},
            {"icons": ["bell", "happy", "pane"], "need": "", "flag": "quest:q_bell_clapper:done"},
        ],
        "reward": {"kind": "pane", "value": "toll_echo", "amount": 1},
    },
    {
        "id": "q_harbor_post",
        "island": 2,
        "kind": "timed_delivery",
        "folk": "ferry_beetle",
        "icon": "quest_timer",
        "time_limit_s": 45,
        "rescue_folk": "ferry_beetle",
        "steps": [
            {"icons": ["toy_skiff", "clock", "arrow_e", "lantern"], "need": "quest:item:harbor_parcel", "consume_item": "harbor_parcel", "flag": "quest:q_harbor_post:s0"},
            {"icons": ["check", "wave", "pane"], "need": "", "flag": "quest:q_harbor_post:done"},
        ],
        "reward": {"kind": "pane", "value": "harbor_wake", "amount": 1},
    },
    {
        "id": "q_canopy_hide",
        "island": 3,
        "kind": "hide_and_seek",
        "folk": "gardener_frog",
        "icon": "quest_hide",
        "rescue_folk": "gardener_frog",
        "steps": [
            {"icons": ["quest_hide", "seed", "eye"], "need": "quest:hide:hollow_stump", "flag": "quest:q_canopy_hide:s0"},
            {"icons": ["happy", "toy_plant", "pane"], "need": "", "flag": "quest:q_canopy_hide:done"},
        ],
        "reward": {"kind": "pane", "value": "vine_snare", "amount": 1},
    },
    {
        "id": "q_dusk_vista",
        "island": 4,
        "kind": "light_view",
        "folk": "scribe_worm",
        "icon": "quest_photo",
        "rescue_folk": "scribe_worm",
        "steps": [
            {"icons": ["quest_photo", "light_on", "isl_4"], "need": "quest:view:mirefen_arch", "flag": "quest:q_dusk_vista:s0"},
            {"icons": ["book", "heart", "pane"], "need": "", "flag": "quest:q_dusk_vista:done"},
        ],
        "reward": {"kind": "pane", "value": "dusk_dew", "amount": 1},
    },
    {
        "id": "q_star_chart",
        "island": 5,
        "kind": "trade_chain",
        "folk": "owl_chick",
        "icon": "quest_trade",
        "rescue_folk": "owl_chick",
        "steps": [
            {"icons": ["star", "trade", "key"], "need": "quest:item:brass_lens", "consume_item": "brass_lens", "give_item": "star_ink", "flag": "quest:q_star_chart:s0"},
            {"icons": ["book", "trade", "star"], "need": "quest:item:star_ink", "consume_item": "star_ink", "flag": "quest:q_star_chart:s1"},
            {"icons": ["star", "happy", "pane"], "need": "", "flag": "quest:q_star_chart:done"},
        ],
        "reward": {"kind": "pane", "value": "zenith_lens", "amount": 1},
    },
    {
        "id": "q_kiln_ember",
        "island": 6,
        "kind": "fetch",
        "folk": "kiln_salamander",
        "icon": "ember",
        "rescue_folk": "kiln_salamander",
        "steps": [
            {"icons": ["ember", "isl_6", "arrow_n"], "need": "quest:item:slag_coal", "consume_item": "slag_coal", "flag": "quest:q_kiln_ember:s0"},
            {"icons": ["flame", "happy", "pane"], "need": "", "flag": "quest:q_kiln_ember:done"},
        ],
        "reward": {"kind": "pane", "value": "bellows_vent", "amount": 1},
    },
    {
        "id": "q_silver_lens",
        "island": 7,
        "kind": "light_view",
        "folk": "mirror_crab",
        "icon": "mirror",
        "rescue_folk": "mirror_crab",
        "steps": [
            {"icons": ["mirror", "light_on", "isl_7"], "need": "quest:view:moon_pool", "flag": "quest:q_silver_lens:s0"},
            {"icons": ["spark", "happy", "pane"], "need": "", "flag": "quest:q_silver_lens:done"},
        ],
        "reward": {"kind": "pane", "value": "glass_step", "amount": 1},
    },
    {
        "id": "q_golden_thread",
        "island": 8,
        "kind": "fetch",
        "folk": "tailor_spider",
        "icon": "quest_rescue",
        "rescue_folk": "tailor_spider",
        "steps": [
            {"icons": ["lantern", "spark", "isl_8"], "need": "quest:item:dawn_spool", "consume_item": "dawn_spool", "flag": "quest:q_golden_thread:s0"},
            {"icons": ["home", "heart", "pane"], "need": "", "flag": "quest:q_golden_thread:done"},
        ],
        "reward": {"kind": "pane", "value": "dawn_spark", "amount": 1},
    },
]

folk_json = {
    "ferry_beetle": {"island": 2, "sheet": "res://luxel/art/folk/ferry_beetle.json", "default_bubbles": [["toy_skiff", "wave", "lantern"]]},
    "moth_kid": {"island": 0, "sheet": "res://luxel/art/folk/moth_kid.json", "default_bubbles": [["moth", "light_on", "happy"]]},
    "bell_snail": {"island": 1, "sheet": "res://luxel/art/folk/bell_snail.json", "default_bubbles": [["bell", "music", "lantern"]]},
    "gardener_frog": {"island": 3, "sheet": "res://luxel/art/folk/gardener_frog.json", "default_bubbles": [["seed", "toy_plant", "happy"]]},
    "owl_chick": {"island": 5, "sheet": "res://luxel/art/folk/owl_chick.json", "default_bubbles": [["star", "eye", "isl_5"]]},
    "kiln_salamander": {"island": 6, "sheet": "res://luxel/art/folk/kiln_salamander.json", "default_bubbles": [["ember", "flame", "pane"]]},
    "mirror_crab": {"island": 7, "sheet": "res://luxel/art/folk/mirror_crab.json", "default_bubbles": [["mirror", "spark", "isl_7"]]},
    "candle_grandma": {"island": 0, "sheet": "res://luxel/art/folk/candle_grandma.json", "default_bubbles": [["home", "heart", "lantern"]]},
    "scribe_worm": {"island": 4, "sheet": "res://luxel/art/folk/scribe_worm.json", "default_bubbles": [["book", "clock", "isl_4"]]},
    "tailor_spider": {"island": 8, "sheet": "res://luxel/art/folk/tailor_spider.json", "default_bubbles": [["pane", "gift", "home"]]},
}

bestiary_weakness = {
    "warden": "weak_heavy", "snatcher": "weak_bolt", "owl": "weak_light",
    "barnacle_sentry": "weak_prism", "gull_thief": "weak_bolt", "crab_warden": "weak_heavy",
    "sporecap": "weak_bolt", "bramble_knight": "weak_heavy", "gloam": "weak_light",
    "lily_hopper": "weak_bolt", "heron_stalker": "weak_heavy", "mire_snuffer": "weak_light",
    "phantom_owl": "weak_light", "orrery_sentinel": "weak_prism", "echo_moth": "weak_bolt",
    "cinder_golem": "weak_heavy", "ash_mole": "weak_bolt", "bellows_imp": "weak_prism",
    "moonshade_warden": "weak_light", "moonshade_snatcher": "weak_light", "moonshade_owl": "weak_light",
    "hollow_wick": "weak_heavy", "bell_warden": "weak_heavy", "bellkeeper": "weak_heavy",
    "tide_captain": "weak_prism", "lighthouse_hermit": "weak_prism", "elder_sporecap": "weak_bolt",
    "briar_matron": "weak_heavy", "great_lily_hopper": "weak_bolt", "heron_abbess": "weak_heavy",
    "clockwork_warden": "weak_prism", "astronomer": "weak_light", "forge_warden": "weak_heavy",
    "kilnmother": "weak_heavy", "spire_warden": "weak_prism", "hollow_wick_boss": "weak_heavy",
    "night_harbinger": "weak_light", "the_hush": "weak_light",
}

toys_catalog = [
    {"id": "push_block", "icon": "toy_block", "name_key": "TOY_BLOCK", "move": ""},
    {"id": "pressure_plate", "icon": "toy_plate", "name_key": "TOY_PLATE", "move": ""},
    {"id": "timed_brazier", "icon": "toy_brazier", "name_key": "TOY_BRAZIER", "move": "bolt"},
    {"id": "crystal_toggle", "icon": "toy_crystal", "name_key": "TOY_CRYSTAL", "move": "bolt"},
    {"id": "moving_platform", "icon": "toy_platform", "name_key": "TOY_PLATFORM", "move": "dash"},
    {"id": "conveyor", "icon": "toy_conveyor", "name_key": "TOY_CONVEYOR", "move": "dash"},
    {"id": "wind_zone", "icon": "toy_wind", "name_key": "TOY_WIND", "move": "wings"},
    {"id": "gravity_well", "icon": "toy_gravity", "name_key": "TOY_GRAVITY", "move": "prism"},
    {"id": "light_plant", "icon": "toy_plant", "name_key": "TOY_PLANT", "move": "throw"},
    {"id": "shadow_gate", "icon": "toy_shadow", "name_key": "TOY_SHADOW", "move": "throw"},
    {"id": "scale", "icon": "toy_scale", "name_key": "TOY_SCALE", "move": ""},
    {"id": "pull_ring", "icon": "toy_ring", "name_key": "TOY_RING", "move": "throw"},
    {"id": "carry_orb", "icon": "toy_orb", "name_key": "TOY_ORB", "move": ""},
    {"id": "lantern_hook", "icon": "toy_hook", "name_key": "TOY_HOOK", "move": "throw"},
    {"id": "echo_rose", "icon": "toy_rose", "name_key": "TOY_ROSE", "move": "wings"},
    {"id": "vehicle_skiff", "icon": "toy_skiff", "name_key": "TOY_SKIFF", "move": "prism"},
]

pack = {
    "pack_id": "folk_panes_e0_5",
    "version": 1,
    "owner": "E0-5",
    "interactables": {
        "npc": "res://luxel/world/folk/npc.gd",
        "quest_item": "res://luxel/world/folk/quest_item.gd",
        "moth": "res://luxel/world/folk/moth.gd",
        "pane_pickup": "res://luxel/world/folk/pane_pickup.gd",
        "shop_npc": "res://luxel/world/folk/shop_npc.gd",
        "hub_door": "res://luxel/world/folk/hub_door.gd",
        "training_dummy": "res://luxel/hub/training_dummy.gd",
    },
    "panes": panes_json,
    "moths": moths_json,
    "quests": quests_json,
    "strings": STRINGS,
}

catalog = {
    "folk": folk_json,
    "moth_tiers": moth_tiers,
    "bestiary_weakness": bestiary_weakness,
    "toys_catalog": toys_catalog,
}

# Verify zero collision with built-in LxStrings.TABLE
strings_gd = (ROOT / "luxel" / "story" / "strings.gd").read_text(encoding="utf-8")
for sid in STRINGS:
    if f'"{sid}":' in strings_gd:
        raise ValueError(f"String ID collision with LxStrings.TABLE: {sid}")

OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
OUT_PATH.write_text(json.dumps(pack, indent=2) + "\n", encoding="utf-8")
cat_path = ROOT / "luxel" / "world" / "folk" / "folk_catalog.json"
cat_path.write_text(json.dumps(catalog, indent=2) + "\n", encoding="utf-8")
print(f"Wrote {OUT_PATH} and {cat_path}: {len(panes_json)} panes, {len(moths_json)} moths, {len(quests_json)} quests, {len(folk_json)} folk, {len(STRINGS)} strings (all validated, 0 collisions)")
