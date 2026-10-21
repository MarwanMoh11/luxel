# Credits

Luxel is a game by **Marwan Abudaif**: concept, game design, technical architecture, story, art and audio
direction, debugging, play-testing and tuning. Implementation by Claude Code (AI coding assistant), working to
Marwan's designs.
Everything not listed below is original to this project and covered by [LICENSE](LICENSE).

## Third-party assets in the game

### Sound effects: Kenney (CC0)

By Kenney ([kenney.nl](https://kenney.nl)), licence: Creative Commons Zero (CC0 1.0,
[creativecommons.org/publicdomain/zero/1.0](https://creativecommons.org/publicdomain/zero/1.0/)).
Credit is not required. We give it anyway.

| Pack | Files used | Where they end up |
|---|---|---|
| [Impact Sounds](https://kenney.nl/assets/impact-sounds) 1.0 | impactSoft_medium_000, impactPunch_heavy_000, impactWood_medium_001, impactTin_medium_000/002/003, impactWood_light_*, impactGlass_light_002, impactPunch_medium_000, impactSoft_heavy_000, impactBell_heavy_000, footstep_grass_000/002, footstep_snow_000/001 | hit, hurt, kill, enemy sounds, star chime, formation cue, crack, the bell toll (`toll.wav`) |
| [Interface Sounds](https://kenney.nl/assets/interface-sounds) 1.0 | tick_002, pluck_001, pluck_002, switch_002, bong_001, glass_001, glass_002, glass_004, scratch_005 | pick, shoot, tab, the sting (`sting.wav`), owl hoot, star home, gloam sounds |
| [RPG Audio](https://kenney.nl/assets/rpg-audio) | handleCoins, metalLatch, bookFlip1/2/3, cloth1-4, clothBelt, creak1-3, dropLeather, handleSmallLeather, handleSmallLeather2 | sell, pause, crack, enemy sounds |

Most files were trimmed, pitched to the song's key (D or A), layered and levelled for the game.
hit, hurt, kill, pick, shoot, sell and tab are the Kenney files unchanged.

No sounds from freesound.org are used.

### Music instruments: MuseScore General soundfont (MIT)

The Lantern Gothic score is original. It uses these instruments from `MuseScore_General.sf2` (v0.2):
celesta, choir aahs, glockenspiel, harp, harpsichord, music box, tubular bells.

MuseScore_General.sf2 is shared under the MIT licence. The required notices:

> FluidR3 (original version) by Frank Wen Copyright (c) 2000-02
>
> Mono conversion (FluidR3Mono) by Michael Cowgill Copyright (c) 2014-17
>
> Adaptation for MuseScore_General.sf2 by S. Christian Collins Copyright (c) 2018-19
>
> Temple Blocks instrument provided by Ethan Winer Copyright (c) 2002
>
> Drumline Cymbals provided by Michael Schorsch Copyright (c) 2016

The MIT permission notice that applies to it is the same text as the Godot notice below, with the
copyright lines above.

### Font

The 3x5 pixel font (`art/ui/font.png`) is original.

### Art

All pixel art is original.

## Godot Engine (MIT)

Luxel runs on [Godot Engine](https://godotengine.org) 4.7.2. Godot asks every game to include its
licence text:

```
Copyright (c) 2014-present Godot Engine contributors (see AUTHORS.md).
Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

Godot bundles third-party libraries with their own licences, among them FreeType (FreeType License),
ENet (MIT) and mbed TLS (Apache 2.0). Portions of this software are copyright (c) The FreeType Project
([freetype.org](https://www.freetype.org)). All rights reserved. The full list is in Godot's
[COPYRIGHT.txt](https://github.com/godotengine/godot/blob/master/COPYRIGHT.txt), and the engine reports it
at runtime through `Engine.get_copyright_info()` and `Engine.get_license_info()`.

## Tools

- [Godot Engine](https://godotengine.org) 4.7.2 (MIT).
- [Claude Code](https://claude.com/claude-code) (Anthropic): implementation, working to Marwan's designs.
