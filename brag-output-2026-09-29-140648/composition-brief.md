# Hyperframes Composition Brief: Galaxy Buds Manager for macOS

## Objective
Create a 23-second, landscape, premium minimal launch film for the native macOS app.

## Output
- Composition: `brag-output-2026-09-29-140648/composition/`
- Video: `brag-output-2026-09-29-140648/brag.mp4`
- 1920x1080, 30 fps, 23 seconds.

## Source material
- `README.md`, `Sources/UI/MenuBar/MenuBarPopover.swift`, `screenshots/menu-app-rounded.png`, `screenshots/app-icon-rounded.png`.
- Real popover capture: `composition/assets/real-menu.png`.
- Illustrative macro earbud image: `composition/assets/earbuds-hero.png`.
- Product scope: detailed controls are only for Galaxy Buds2 Pro (SM-R510). No implication that other models have these controls.

## Creative direction
Premium minimal product film: stable compositions with meaningful animation within shots. Avoid static posters, uniform card grids, generic SaaS language, fabricated app states, and rapidly flashing copy. Use the real menu capture alongside accurately recreated UI motion.

## Visual identity
- Background `#0B111B`, accent `#2F8BFF`, text `#F5F8FF`.
- System sans typography, heavy headlines and precise smaller labels.
- Earbud photography, macOS menu bar and actual app popover.

## Storyboard
Follow `../brag-plan.md`: product light (0-3.5), menu bar reveal (3.5-7), batteries (7-11.5), noise control (11.5-16.5), feature focus (16.5-20), closing (20-23).

## Audio
- Original `assets/music.wav`, mixed as a restrained bed with short tactile cues on UI motion.
- Avoid voiceover.

## Hyperframes implementation
Use a single seek-safe GSAP timeline, local media and fonts, and native Hyperframes timing attributes. Run `check` before rendering and inspect frames at settled moments. Frame 0 should be replaced by the chosen poster frame.
