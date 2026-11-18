# Hinge Pop: short-form clips

`npm run clips` makes these in `dist-clips/` (gitignored). Each one is a single master MP4: 1080x1920, H.264 High,
30 fps, a silent AAC track, no watermark. The same file goes to TikTok, YouTube Shorts and Instagram Reels; upload it
to each app directly, never a file saved back out of another app (that carries its watermark). Add a sound inside
each app: the clips are silent so a trending track can go on top.

Every clip is the web game at mutaafaziz.com/hingepop/play, recorded from the guest-free build (the same cuts as the
portal builds, so no guest stars) with a scripted player. Captions say only what the web game does. Villains are in
the native app only, so no clip mentions them. Check `dist-clips/qa/<id>.png` (0 s, 1 s, middle and end, with the
apps' button areas outlined) before posting.

## Post first

**hp-snap.** It leads with the game's signature move, Snap the Hinge: a drag off the line flings the bubbles back.
Then post **hp-cleared** and **hp-faceoff** as the A/B against it (a payoff-first hook and a two-player hook).

## The clips

| Clip | Hook (first second) | Length |
| --- | --- | --- |
| hp-snap | The hinge snaps and flings a bubble back | ~17.5 s |
| hp-cleared | The Level cleared card tallies the run | ~15 s |
| hp-swipe | A rush of swipes mid-level, splits everywhere | ~17.5 s |
| hp-faceoff | The two-player result: one half wins, one loses | ~21 s |
| hp-worlds | Magma, frost, space, neon, classic arenas in a row | ~15.5 s |

## Captions and hashtags

Pinned comment or post text for every clip: **Play free in your browser: mutaafaziz.com/hingepop**

- **hp-snap:** Snap the hinge to fling them back. Free in your browser, no download. #hingepop #browsergames #indiegame #puzzlegame
- **hp-cleared:** Split them all before they cross the line. #hingepop #browsergames #indiegame #satisfying
- **hp-swipe:** One swipe hits every bubble it crosses. #hingepop #browsergames #indiegame #mobilegames
- **hp-faceoff:** Lay the phone flat and face off, one half each. #hingepop #twoplayergames #browsergames #indiegame
- **hp-worlds:** A new world every ten levels. How far do you get? #hingepop #browsergames #indiegame #puzzlegame

## Re-cutting

Edit `store/clips/clips.json` (segments, speeds, captions) and run `npm run clips -- --skip-capture` to re-cut from
the takes already recorded, or `npm run clips -- --only=hp-snap` for one clip. A new take (another level, another
player style) goes in `TAKES` in `scripts/clips.mjs`.
