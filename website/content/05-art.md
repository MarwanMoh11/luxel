---
id: art
tab: GRAPHICS
title: THE LAST LIGHT LOOK
kicker: 20 COLOURS. ONE LOW SUN.
---

Every pixel in Luxel is one of 20 colours, lit by one low sun in the west. The look is called Last Light: an island garden in a starry void at the last minute of sunset. Hushed, golden, a little melancholy.

## THE RULES

- 320x180 pixels, scaled by whole numbers with nearest filtering, so every pixel stays square.
- Top-down three-quarter view, like A Link to the Past or Eastward. Characters are about 24 pixels tall.
- One sun in the west-north-west. Lit faces are left and top. Shadows fall long to the lower right, about 0.8 times the height of what casts them, one palette step darker, with a dithered tail.
- Warm west, cool east: gold rims and flecks in the west, sky and ice highlights past the river.
- Lit-side outlines. The shadow side gets the darkest night colour; the sunlit side gets one shade darker than the pixel it touches. No ink-black lines anywhere.
- Glows are painted with palette colours and one 4x4 ordered dither, anchored to the world so neighbouring pieces line up. Nothing is blended or additive.
- No text in the world, no neutral greys and no pure black. The darkest colour, void, belongs to the sky.

## THE PALETTE

Twenty colours, for everything: sprites, map, effects, menus and text.

| | | | | |
|---|---|---|---|---|
| void #0d0b1e | night #211a3b | dusk #3d2c5c | plum #6a3d6f | wine #a0466a |
| coral #e2725b | apricot #f5a96a | gold #ffd98c | cream #fff4dc | pine #1d3d4c |
| teal #2b6b68 | jade #4c9e78 | lime #a3cf7d | deep #263873 | blue #3e6db0 |
| sky #78a9da | ice #c7e5ef | mauve #8a6e91 | stone #c2a7ae | rose #ec9fa8 |

## BEAUTIFUL, THEN BROKEN

The whole game is about selling the way it looks, so the art has two jobs at once. The world has to be gorgeous at full settings, so every sale visibly costs something, and still readable when it is degraded: 4 colours, 2 colours, half brightness, 2 to 4 pixel blocks.

- Values are planned for the worst case: walkable ground is mid-dark, paths mid, props light on top and dark at the base. Every zone has one landmark you can read in two colours at 4-pixel blocks.
- Anything that gives off light also draws itself switched off, so BRIGHTNESS can swap in the dark version.
- Each zone stars a setting you can sell: lights, particles, animation, stained-glass colour, fine detail, the stars.
- Enemies stay readable in every mode. At 2 colours their eyes and one light edge survive; at 4-pixel blocks the silhouette alone says which enemy it is.
- ANIMATIONS freezes every sprite on frame 1, so frame 1 of every loop is a good still pose, and frame 1 of every warning animation already shows the warning.

## THE HOP RULE

Anything that moves in four directions has side, front and back frames, and every move plays a hop: crouch, air, land. A side view alone looks wrong on up and down moves. Secondary parts, like Wick's antennae and hem, lag one frame behind the body. The Parasol Toad goes further, with eight facings, because which way its parasol points is the whole mechanic.

## MOTION

The world loops on a 2-second cycle at 12 frames a second, and every frame count divides 24. Motion is subtle and nothing flashes. Screen shake is only for taking damage, and you can sell that too.

## THE TITLE

LUXEL is written in luxels: each lit pixel of the 3x5 font is a 4-pixel lamp on a night grid. On the title screen they light west to east with a lantern note each, and their light spills out over the grove. When you press a key, the dark eats the title east to west in 0.6 seconds, the intro's lights-out in small. At the end of the ending, the same luxels fly out of Wick's lantern and build the name again.
