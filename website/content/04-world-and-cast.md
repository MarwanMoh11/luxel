---
id: world
tab: ISLAND
title: WORLD AND CAST
kicker: AN ISLAND AT THE LAST MINUTE OF SUNSET
---

At sunset the dark comes to eat the island's light, and every night Wick the lamplighter carries one lantern out and lights it all again. Tonight the dark is hungrier, so the lantern takes the only light it has left to reach: the game you are playing.

There is no lore beyond that. The trade is with the lantern: it buys settings and pays in power. The enemies are the dark. They ate light, so a kill gives light back.

## WICK

A lamplighter moth with a wine wing-cloak marked with sunset eye-spots, an ice ruff and leaf antennae. Gold and cream show on Wick only where the lantern lights them. About 24 pixels tall. Wick never talks.

- Drawn in three views (side, front, back), and every move plays a hop.
- 93 sprite sheets: the body, the lantern at three glow tiers, the shadow and the hit flash.
- One-shot animations carry the story: the spawn drop, the cast, the level-up raise, the sell, and the ending's sit-down with the lantern in Wick's lap.

## THE LANTERN

The only weapon, and the only light BRIGHTNESS never sells. It aims at the nearest enemy and fires on its own. It glows brighter as it grows, in three tiers, and each power gives its shots the form of one of the island's places.

| Form | From | Lit by | What it does |
|---|---|---|---|
| Ember | the lantern | always | The base shot |
| Fireflies | the lantern grove | fire rate | 2, 3, then 5 flies orbit Wick and dart at enemies within 72 px |
| Bell toll | the bell tower | damage | The impact rings out and hurts every other enemy it reaches, 50/65/80% of the shot |
| Moon trail | the moon pool | range | The shot leaves glints that hurt whatever crosses them |
| River wake | the river | speed | Every hop that lands hurts enemies around Wick's feet and pushes them away |
| Star needle | the observatory | pierce | Shots pass through enemies |
| Prism shards | the glasshouse | extra shots | A fan of shots |
| Sundial ring | the sundial | a heart gained | A healing ring at Wick's feet |
| Blast | everything you sold | CONFIRM SALES | One ring that clears the island (finale) |


## LIGHT SHARDS

Every kill drops light shards. They pop out, hover a moment, then the lantern drinks them one by one along a curve. There is nothing to walk over and pick up. Each arrival is timed to land on a 16th note of the music, and its chime climbs the scale as the lantern fills, from a low D to a high D. The shard that fills it sets off a chord that wants to resolve, and the menu's sting resolves it.

## THE ISLAND

An island garden floating in a starry void, at the last minute of sunset. The sun is sinking past the west rim; the east is already in moonlight. The world is 1280x720 pixels, four screens by four, in seven zones:

| Zone | Where |
|---|---|
| The lantern grove, with the Lantern Mother (the great tree, never named) | north-west |
| The bell tower | north |
| The sundial court, where Wick lands | centre |
| The river, the bridge and the falls | east |
| The glasshouse | south |
| The observatory and the moon pool | west and south-west |
| The edge: sky, rim, cliffs and stars | all around |

- 298 props, 166 of them animated on a 2-second loop. 92% of the island top is walkable, with a path ring through every zone.
- Every prop has a job (landmark, cover, obstacle, crossing, boundary, guide, tell or showcase) and a written purpose. The 145 collision shapes are traced from the pixels each object stands on, and cover and landmarks stop shots as well as feet.
- The island is built to lose its settings. BRIGHTNESS switches 25 lit props to lights-off versions. PARTICLES takes away 35 motes, fireflies and petals. ANIMATIONS freezes all 166 animated props. SOUND stops the five bells and chimes. PIXELS puts out the 65 twinkling stars, and then the 2,290 painted star pixels one by one.

## THE DARK

Six enemies, and each asks for a different way of moving: mow, sidestep, chase, flank, weave, and keep close to the light. Each one's warning lives in a setting you can sell, so every sale is a real trade against what is on the field.

They share a family look: cool violet bodies, never gold or cream (that is Wick's light), and a pair of pale eyes as the brightest part. In the finale they are reduced to just those eyes.

| Enemy | From | What it does | How to beat it | Sales that hurt |
|---|---|---|---|---|
| Snuffer | 0:00 | A small creature under a candle-snuffer hood. Walks straight at you in loose packs, later in rings that close in. Its cone pops off spinning when it dies. | Mow it down. | RESOLUTION, COLOURS |
| Hush Owl | 0:40 | The moth's natural predator. Circles, locks on with a soft hoot, then dives through where you stood and overshoots. It can only be shot in the dive and the stumble after. | Step aside, then shoot it. | SOUND, ANIMATIONS, FRAME RATE, INPUT DELAY, ICE, UP KEY |
| Magpie | 1:10 | A thief with a stolen star in its beak. It never attacks. It flees when you close in and leaves after about 9 seconds. | Catch it for a free level-up. The lantern only shoots the nearest enemy, so you have to run through the crowd: risk for reward, the theme in miniature. | RESOLUTION, AIM ASSIST, ICE |
| Parasol Toad | 1:30 | A heavy toad holding a lace parasol like a shield. The parasol turns toward you and blocks every shot from the front, pierce included. When it dies, the parasol floats away on the wind. | Circle it and hit it from behind. | HIT FLASH, SOUND, AIM ASSIST, ICE, UP KEY |
| Sporecap | 2:15 | A night toadstool that falls as a spore (its shadow grows where it will land), roots, swells, and puffs rings of eight spores. | Find the gap, or walk in and kill it. | ANIMATIONS, SOUND, FRAME RATE, COLOURS, RESOLUTION |
| Gloam | 3:00 | A long-eared hare cut out of the starry void. Outside the light only its eyes show. It stalks in zig-zag dashes. It dies by unravelling into stars. | Keep it in the lantern's light. | BRIGHTNESS, RESOLUTION, COLOURS |

From 3:30, formations every 22 seconds: Snuffer rings, owl parliaments, toad lines, spore gardens and Gloam packs. Each newcomer gets a one-line tip at its debut, such as OWLS DIVE WHERE YOU STOOD. STEP ASIDE., until you sell TIPS.

