# Submitting Hinge Pop to CrazyGames and GameDistribution

Everything except the accounts and the submit button is ready. Plan on about 10 minutes per portal.

The portal builds are separate from the live game at mutaafaziz.com/hingepop, which they never change (`npm run build` makes the same bytes as before):

- They use relative paths.
- Each loads the portal's own SDK and no Box Office analytics.
- They make no calls to mutaafaziz.com, or to any other server.
- They have no links of any kind, no landing page, no store buttons, no share button and no install prompt.

## What the portal builds can and can't do

| Feature | On a portal |
| --- | --- |
| The game: endless levels, Snap the Hinge, swipe to slice, chain pops, two players, the guided tours, Settings | Same as the web |
| Guest stars | Not in the portal builds. Several wink at famous films and characters, and both portals forbid third-party trademarks and likeness without consent (CrazyGames Developer Terms 4.4(a)(iv), GameDistribution Developer Agreement 2.6.2). Guests never blocked a clear or touched the meter, so every level plays and clears the same without them (`test/portal.test.mjs` plays levels 1 to 60). The tour's last line and the How to play section no longer mention them, and their art is not in the zip. The build fails if a guest's name or art reaches it. |
| Analytics | None. The web's `track()` calls do nothing (GameDistribution 2.6.8 bans tracking). |
| The landing page embedding | Off. The game never talks to a parent page. |
| Screen wake lock | Only where the portal's frame allows it. Otherwise the screen follows the device's own setting. |
| Sound | Off until the player turns it on, as on the web. CrazyGames' mute setting wins over the game's Sound toggle. |
| Saves (level reached, best score, settings, tours seen) | CrazyGames: through its data module, so signed-in players keep progress across devices, with localStorage as the fallback. GameDistribution: localStorage. |
| Ads | Only through the portal's SDK. A midgame ad shows when you leave a result (Level N, Try again, Menu, or Rematch and Menu after two players). Never after a session's first game, never more than once every 3 minutes (the SDKs enforce their own limits too), never during play or a pause. No rewarded ads. |
| Ad blocker | The game plays the same with the SDK blocked. There are no ads and nothing waits for them. |

## Build (run once per portal, from the repo root)

```
npm run build:crazygames          # → dist-portals/hinge-pop-crazygames.zip
npm run build:gamedistribution    # → dist-portals/hinge-pop-gamedistribution.zip (paste the game id first, below)
```

Each command builds the portal's `index.html` from the game's own `index.html`, adds only the art the game loads and its two fonts with their licence (`fonts/OFL.txt`), and checks the result. It fails if it finds a guest star's name or art, mutaafaziz.com, Box Office, a `/hingepop/` or root-absolute path, a path above the game folder, a link, a store or device name, an outbound address, a service worker or a fullscreen call. Then it zips the game with `index.html` at the zip's root. Last build: 20 files, 0.60 MB unzipped, 0.52 MB zipped.

To check a build before you upload it:

```
node scripts/portal-playtest.mjs crazygames            # a fresh player: tour, two levels, the break, two players, in a sandboxed iframe on another origin
node scripts/portal-playtest.mjs crazygames --blocked  # the same with the SDK blocked (an ad blocker)
node scripts/portal-playtest.mjs crazygames --phone    # 390×844, every input a real tap
```

## CrazyGames

1. **Sign up** at https://developer.crazygames.com/ as a developer.
2. **Create the game** at https://developer.crazygames.com/games (Submit a game). Choose **HTML5**.
3. **Upload** `dist-portals/hinge-pop-crazygames.zip`.
4. **Preview it in the QA tool** in the Developer Portal. Its SDK shows stand-in ads there. Check three things:
   - "Gameplay start" appears when a level starts (or the tour, on a first visit).
   - "Gameplay stop" appears on the result, and on pause.
   - A midgame request appears when you leave the second game's result.
5. **Fill in the fields:**
   - **Name:** `Hinge Pop`
   - **Description:** paste `store/portals/crazygames/description.txt`
   - **Controls:** paste `store/portals/crazygames/controls.txt`
   - **Category:** Casual. If the form offers Arcade instead, use that.
   - **Tags:** Bubble, Arcade, Casual, 2 Player, Tap, Mouse, Skill. Pick whichever of these the form offers.
   - **Platforms:** Desktop and Mobile. The game takes mouse and touch and lays itself out for phones and tablets.
   - **Orientation:** Both. The game lays itself out either way up. If the form wants one, choose Portrait.
   - **Progress save:** ON (data module). The game saves through it.
   - **Account integration / user module:** No.
   - **Multiplayer:** No online play. Two players share one device; if the form has a local or same-device option, tick it.
   - **Sitelock:** None.
   - **Privacy notice:** Not needed. The portal build collects no personal data and sends nothing anywhere.
6. **Upload the covers** from `store/portals/crazygames/`:
   - `cover-landscape-1920x1080.png` (16:9)
   - `cover-portrait-800x1200.png` (2:3)
   - `cover-square-800x800.png` (1:1)

   They are real frames of level 34 being played, with only the game's logo on them, as the cover rules ask.
7. **Upload the videos** from `store/portals/crazygames/`. CrazyGames requires both:
   - `video-landscape-1920x1080.mp4`
   - `video-portrait-1080x1620.mp4`

   Each runs 18 s at real speed, has no audio, and opens on the cover. Each is real footage of level 34 played with real pointer input (taps and swipes), with the HUD visible.
8. **Submit.** The game goes to Basic Launch first, where CrazyGames turns ads off and the game runs without them. The SDK is already integrated, as Full Launch requires: gameplay and loading events, midgame ads, the data module and the mute setting.

## GameDistribution

1. **Sign up** at https://gamedistribution.com/ as a developer. The dashboard is at https://developer.gamedistribution.com/.
2. **Create the game** in the dashboard (Upload / Add game). Copy its **Game ID** (the hash).
3. **Add the id to the build.** Open `portal/config.js` and replace `'PASTE-GAMEDISTRIBUTION-GAME-ID'` on the line `export const GD_GAME_ID = ...` with the id in quotes. Then run `npm run build:gamedistribution`. The build warns if the id is still the placeholder. Without the id the game runs but shows no ads, because the SDK isn't loaded. To try an id without editing the file, use `HP_GD_GAME_ID=<id> npm run build:gamedistribution`. Commit the id afterwards so later builds keep it.
4. **Upload** `dist-portals/hinge-pop-gamedistribution.zip`.
5. **Fill in the fields:**
   - **Title:** `Hinge Pop`
   - **Description:** paste `store/portals/gamedistribution/description.txt`
   - **Instructions:** paste `store/portals/gamedistribution/instructions.txt`
   - **Category:** Casual, or Arcade if the form offers it.
   - **Tags:** bubble, arcade, casual, 2 player, tap, skill
   - **Mobile:** yes, both orientations. If the form wants one, choose Portrait.
   - **Language:** English
   - **Rewarded ads:** leave it OFF. The game doesn't use them.
6. **Upload the images** from `store/portals/gamedistribution/`: `image-1280x720.png`, `image-1280x550.png`, `image-512x512.png`, `image-512x384.png` and `image-512x340.png`.

   GameDistribution doesn't publish these sizes. They come from its asset template, as COLD GAS found. If the form asks for another size, run `node scripts/portal-art.mjs --covers`. It writes from the same frames, and you can add a size in that script's GameDistribution list.
7. **Activate the SDK** (GameDistribution's wiki, SDK Implementation, "Activate the SDK"):
   - In the upload view, open the game in its iframe. A debug bar shows above it.
   - Request an ad from the debug bar and watch it to the end. If the bar isn't there, open the browser console in the game's frame and run `gdsdk.openConsole()`.
   - The flag can take up to two weeks.
8. **Request publishing** from the dashboard.

## Decisions for you

- **A pre-roll on GameDistribution.** GameDistribution's wiki calls a pre-roll on the Play button "best practice". The game doesn't show one, because the house rule is no ad before the first game. Adding one would be a small change in `portal/runtime.js` (`advertisementSettings.autoplay`).
- **Rewarded ads.** None. The web game has nothing a reward could honestly give (no lives, no currency, no continues).
