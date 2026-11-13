// The one place a portal build reads its settings from (store/portals/SUBMIT.md). scripts/portal-html.mjs hands these
// to portal/runtime.js inside the portal build's index.html. The live site at mutaafaziz.com/hingepop never reads them.
//
// GameDistribution's game id: it exists only once the game is created in the GameDistribution developer dashboard
// (developer.gamedistribution.com, your game, the "Game ID" hash). Paste it here, then `npm run build:gamedistribution`
// and upload the new zip. Until then the build warns, and the game runs with no ads (the SDK is not loaded).
// `HP_GD_GAME_ID=<id> npm run build:gamedistribution` overrides it for one build.
export const GD_GAME_ID_PLACEHOLDER = 'PASTE-GAMEDISTRIBUTION-GAME-ID';
export const GD_GAME_ID = 'PASTE-GAMEDISTRIBUTION-GAME-ID';

// How long the game waits for the portal's SDK before it starts without it. An ad blocker fails at once; this is for
// a slow network. Saves are read once the wait is over, so an SDK that lands later is never used.
export const SDK_WAIT_MS = 5000;

// Between-games breaks: never after the first game of a session, and at most one midgame ad every 3 minutes (our own
// floor; the SDKs keep theirs too: CrazyGames one midgame per 3 minutes, GameDistribution its own interval).
export const MIDGAME_GAP_MS = 180_000;
