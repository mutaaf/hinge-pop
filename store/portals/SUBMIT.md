# Submitting Hinge Pop to CrazyGames, GameDistribution, itch.io and Newgrounds

Everything except the accounts and the submit button is ready. Plan on about 10 minutes per portal.

The portal builds are separate from the live game at mutaafaziz.com/hingepop, which they never change (`npm run build` makes the same bytes as before):

- They use relative paths.
- CrazyGames and GameDistribution load the portal's own SDK. itch.io and Newgrounds load no SDK and show no ads. None loads Box Office analytics.
- They make no calls to mutaafaziz.com, or to any other server.
- They have no landing page, no store buttons, no share button and no install prompt. CrazyGames and GameDistribution have no links of any kind. itch.io and Newgrounds have exactly one, "More games at mutaafaziz.com" (see [The link back](#the-link-back)).

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

## itch.io and Newgrounds

Both builds are the same game as the CrazyGames build, guest stars removed in the same way (the same edits, the same gate, and `test/portal.test.mjs` checks every portal), with three differences:

- **No ads and no SDK.** Nothing is loaded from any other server. Saves stay in the browser's localStorage. `portal-playtest.mjs` fails if the game asks any other server for anything.
- **One link back.** The menu ends with a small "More games at mutaafaziz.com" line under Settings. It shows on the menu only: never in play, on a pause or on a result. It opens a new tab only when the player taps it, and the game stays on its menu. The link carries `utm_source=itch.io` or `utm_source=newgrounds` with `utm_campaign=hingepop`, so Box Office on mutaafaziz.com can count the visits each portal sends.
- **Stricter gate.** The build fails if the link is missing or appears twice, or if there is any other link, mention of mutaafaziz.com or outbound address.

### The link back

Rules read on 2026-11-18:

- **itch.io.** The HTML5 upload docs (https://itch.io/docs/creators/html5) set no rule on links or ads. The Quality Guidelines (https://itch.io/docs/creators/quality-guidelines) say: "We prefer to see projects that have no advertisements", and ask creators not to make players go through third-party links to get the game. Our build has no ads, the game is fully playable on itch.io, and the one link is optional.
- **Newgrounds.** Game Guidelines (https://www.newgrounds.com/wiki/help-information/terms-of-use/game-guidelines): "Your submission must not auto-redirect to a new site or open pop-ups", "Your game must not be shovelware made to serve ads or promote your site", and "It would be best if your game does not rely on any calls to third party servers. If you are using a third party API or anything that could be used to track a user, you must give notice". Our link never opens on its own. The game makes no calls to any server and tracks nothing. Newgrounds blocks automated readers, so this was read through the Wayback Machine's 2026-11-08 copy of the page.
- **Newgrounds and AI.** The same page says: "please do not share any games that were generated via an AI prompt", and "If you do utilize AI in any aspect of your game, please disclose what and how it was used in the author commentary." Hinge Pop was built with AI coding help, so `store/portals/newgrounds/author-comments.txt` says how. Read it and correct anything that isn't right before you paste it. Newgrounds moderators decide these case by case.
- **Guest stars.** Both sites ask that you own what you upload (Newgrounds: "You must be the creator and owner of the game you are submitting"), so the film-nod guests stay out here too.

### Build and check

```
npm run build:itch          # → dist-portals/hinge-pop-itch.zip
npm run build:newgrounds    # → dist-portals/hinge-pop-newgrounds.zip
node scripts/portal-playtest.mjs itch            # tour, two levels, two players, then the link opens a new tab
node scripts/portal-playtest.mjs newgrounds
node scripts/portal-playtest.mjs itch --phone    # 390×844, every input a real tap
node scripts/portal-art.mjs --listings           # the cover, the Newgrounds icons and the screenshots (build itch first)
```

Last build: 20 files, 0.60 MB unzipped, 0.52 MB zipped. Both sites take a zip with `index.html` at its root.

### itch.io: owner steps

1. **Sign up** at https://itch.io/register. Then open https://itch.io/game/new (Dashboard, Create new project).
2. **Title:** `Hinge Pop`. **Project URL:** `hinge-pop` is a good choice.
3. **Short description or tagline:** paste `store/portals/itch/tagline.txt`.
4. **Classification:** Games. **Kind of project:** HTML.
5. **Release status:** Released. **Pricing:** No payments (or "Donate" if you want a tip jar).
6. **Uploads:** upload `dist-portals/hinge-pop-itch.zip` and tick **This file will be played in the browser**.
7. **Embed options:**
   - Embed in page, viewport **960 × 600**. The game lays itself out for any shape.
   - Tick **Mobile friendly**, orientation **Default** (it plays either way up). If you must pick one, choose Portrait.
   - Leave **Click to Play** on (the default).
   - Tick **Fullscreen button**.
   - Leave **SharedArrayBuffer support** off.
8. **Description:** paste `store/portals/itch/description.txt`, then a "Controls" heading and `store/portals/itch/controls.txt`. You may add a last line, "More games at https://mutaafaziz.com".
9. **Genre:** Action. Puzzle also fits if you'd rather.
10. **Tags (up to 10):** arcade, casual, bubbles, local-multiplayer, 2-player, endless, score-attack, touch, colorful, singleplayer
11. **AI generation disclosure:** if the form asks, say yes: code written with AI assistance. No AI-generated images, sound or text in the game.
12. **Cover image:** `store/portals/itch/cover-630x500.png`.
13. **Screenshots:** the four `store/portals/itch/screenshot-*.png`, in order (the menu, levels 34 and 12, and a phone-shaped frame of level 21). They are real frames with the game's interface on.
14. **Visibility:** Draft, then **View page** and play a level in the embed. Check the menu link opens a new tab. Then set it to **Public** and save.

### Newgrounds: owner steps

1. **Sign up** at https://www.newgrounds.com/passport (free).
2. **Start a project:** the upload arrow in the header, then Game.
3. **Upload** `dist-portals/hinge-pop-newgrounds.zip`. If you see a 403 in the preview, the zip has its `index.html` in a folder: rebuild, don't re-zip by hand.
4. **File settings** (they appear after the upload): width **960**, height **600**. Tick **Touchscreen friendly**. Leave scrollbars off. If there is a fullscreen option, allow it.
5. **Title:** `Hinge Pop`.
6. **Icon:** `store/portals/newgrounds/icon-1440x810.png`. Newgrounds publishes no icon size, but its game pages show icons at 16:9 (720 × 405 and 480 × 270). `icon-720x405.png` is there if the form wants it smaller. Its small icons crop the middle; the logo sits in the middle.
7. **Description / short description:** paste the first paragraph of `store/portals/newgrounds/description.txt`.
8. **Author comments:** paste `store/portals/newgrounds/author-comments.txt`, after you've checked it.
9. **Instructions** (if the form has the field): the Controls part of `store/portals/newgrounds/description.txt`.
10. **Genre:** Skill, or Action if Skill isn't offered.
11. **Tags (up to 4):** bubbles, arcade, 2-player, casual
12. **Rating:** E (Everyone).
13. **API Tools / Medals / Scoreboards:** skip. The build doesn't use the Newgrounds API.
14. **Preview,** play a level, then **Publish.** New games go through a few days of judging by players, and Newgrounds allows two submissions a day.

### What else to decide

- **Newgrounds and AI.** Newgrounds can remove a game for AI use "at our discretion". The disclosure is honest and the art is drawn in code, but if you'd rather not take the chance, publish only on itch.io.
- **Newgrounds medals and scoreboards.** Not in this build. They would need the Newgrounds API (a client library and a server call, which their guidelines say to announce).
