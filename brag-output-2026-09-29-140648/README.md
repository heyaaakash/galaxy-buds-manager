# Galaxy Buds Manager launch video

The final 23-second, 1920 × 1080 launch video for [Galaxy Buds Manager](https://github.com/heyaaakash/galaxy-buds-manager).

- [Watch or download the MP4](brag.mp4)
- [Poster image](brag.jpg)
- [Share caption](share-copy.txt)
- [Storyboard](brag-plan.md)
- [Hyperframes composition](composition/index.html)

The video animates a menu bar interaction, three battery readings, and the Buds2 Pro noise selector. The popover is a real app screenshot. The earbud close-up is an illustrative generated image. The battery percentages are from that screenshot, not a live reading.

Detailed controls shown in the film apply to Galaxy Buds2 Pro (SM-R510). Other recognized models have experimental battery and placement display only; see the repository's [capability matrix](../Docs/CAPABILITY_MATRIX.md).

## Rebuild

On macOS, install Node.js 22 or newer, FFmpeg, and a Chromium browser supported by Hyperframes. From this folder:

```sh
./build-video.sh
```

The script validates the composition, renders the MP4, picks the settled product frame at 1.8 seconds as the poster, and makes that image frame 0 for social previews. The included `composition/assets/music.wav` is the original synthesized soundtrack. To regenerate it, use Python 3 with NumPy and run `python3 composition/generate_audio.py` from the `composition/` directory.

## Asset and tool notes

- `composition/assets/gsap.min.js` is GSAP 3.14.2, © GreenSock/Webflow. It retains its copyright header and is distributed under the [GSAP Standard License](https://gsap.com/community/standard-license/), separate from this repository's GPL license.
- `composition/assets/earbuds-hero.png` is generated illustrative artwork, not an official Samsung product photograph.
- `composition/assets/real-menu.png` and `composition/assets/app-icon.png` are copies of the repository's app images, kept here so the composition is self-contained.
