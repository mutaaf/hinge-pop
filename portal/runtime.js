// The portal side of a portal build (store/portals/SUBMIT.md). scripts/portal-html.mjs inlines this file into the
// portal build's index.html, ahead of the game, and calls hingePopPortal(config). The live site never loads it.
//
// One surface over the CrazyGames SDK v3 and the GameDistribution HTML5 SDK, so the game never names either. Every
// call is safe without an SDK (an ad blocker, a slow network, the wrong domain): it does nothing, and an ad resolves at
// once with no ad. Nothing here ever throws into the game.
//
//   const p = hingePopPortal({ portal, gdGameId, sdkWaitMs, midgameGapMs }, { win, doc, now, load })
//   await p.boot()        loads and starts the SDK (never rejects; p.live says if it's up), then loadingStart
//   p.ready()             loadingStop, once the game's first screen is up
//   p.attach(hooks)       the game's own hooks: pauseGame, pauseAudio, resumeAudio
//   p.sync(mode)          every frame: 'play' and 'tour' are gameplay, anything else is a break (gameplayStart/Stop
//                         only on a change, and never while an ad is up)
//   p.ran()               a game reached its result
//   p.leave(go)           a result sheet is being left: the midgame ad if one is due, then go(). Never after the first
//                         game of a session, at most once per midgameGapMs, and go() waits until the ad is over.
//   p.muted()             the portal's mute setting (CrazyGames), which wins over the game's Sound toggle
//   p.getItem / setItem   saves: CrazyGames' data module when it's up, localStorage always as the fallback
//
// Sources: docs.crazygames.com/sdk (intro, game, video-ads, data, user) and github.com/GameDistribution/GD-HTML5/wiki
// (SDK-Implementation), as COLD GAS read them on 2026-11-13.
/* exported hingePopPortal */
// eslint-disable-next-line no-unused-vars
function hingePopPortal(cfg, env = {}) {
  const win = env.win || globalThis.window, doc = env.doc || globalThis.document;
  const now = env.now || (() => Date.now());
  const kind = cfg.portal, ms = cfg.sdkWaitMs || 5000, gap = cfg.midgameGapMs || 180000;
  const CG_SDK_URL = 'https://sdk.crazygames.com/crazygames-sdk-v3.js';
  const GD_SDK_URL = 'https://html5.api.gamedistribution.com/main.min.js';
  const PLAY = new Set(['play', 'tour']);

  const safe = (f) => { try { return f(); } catch (e) { return undefined; } };
  const withDeadline = (p, t, fallback) => Promise.race([p, new Promise((r) => setTimeout(() => r(fallback), t))]);
  /** Adds a <script> once; resolves true when it loaded, false on an error (blocked) or after the wait. */
  function loadScript(src, id) {
    return new Promise((done) => {
      if (!doc || !doc.createElement) { done(false); return; }
      if (id && doc.getElementById(id)) { done(true); return; }
      const s = doc.createElement('script');
      if (id) s.id = id;
      s.async = true;
      s.src = src;
      const t = setTimeout(() => done(false), ms);
      s.onload = () => { clearTimeout(t); done(true); };
      s.onerror = () => { clearTimeout(t); done(false); };
      (doc.head || doc.documentElement).appendChild(s);
    });
  }
  const load = env.load || loadScript;

  let live = false, loading = 0, playing = null, busy = false, runs = 0, lastAt = 0, blocker = null;
  let muteAudio = false, hooks = {};
  const call = (name) => safe(() => hooks[name] && hooks[name]());

  // --- CrazyGames -----------------------------------------------------------------------------------------------
  const cg = () => (live && kind === 'crazygames' && win.CrazyGames ? win.CrazyGames.SDK : null);
  async function initCG() {
    if (!(await load(CG_SDK_URL))) return;
    const sdk = win.CrazyGames && win.CrazyGames.SDK;
    if (!sdk || !sdk.init) return;
    try { await withDeadline(Promise.resolve(sdk.init()), ms, null); } catch (e) { return; }
    // 'disabled' (any other domain): every call throws. 'local' (localhost) and 'crazygames' work.
    if (sdk.environment === 'disabled') return;
    live = true;
    const read = () => { muteAudio = !!safe(() => sdk.game.settings.muteAudio); };
    read();
    safe(() => sdk.game.addSettingsChangeListener(read));
  }
  function cgMidgame(h) {
    const sdk = cg();
    if (!sdk || !sdk.ad || !sdk.ad.requestAd) return Promise.resolve(false);
    return new Promise((done) => {
      let started = false, settled = false;
      const end = (ok) => {
        if (settled) return;
        settled = true;
        if (started) safe(() => h.afterAd());
        done(ok);
      };
      try {
        sdk.ad.requestAd('midgame', {
          adStarted: () => { started = true; safe(() => h.beforeAd()); },
          adFinished: () => end(true),
          adError: () => end(false),   // unfilled, adblock, adCooldown, adsDisabled (Basic Launch), other
        });
      } catch (e) { end(false); }
    });
  }

  // --- GameDistribution --------------------------------------------------------------------------------------------
  let gdHooks = null, gdPaused = false;
  const gd = () => (live && kind === 'gamedistribution' ? win.gdsdk : null);
  async function initGD() {
    const id = cfg.gdGameId;
    if (!id || id === cfg.gdPlaceholder) return;   // no id pasted yet (portal/config.js): no SDK, no ads
    let ready;
    const gdReady = new Promise((r) => { ready = r; });
    win.GD_OPTIONS = {
      gameId: id,
      advertisementSettings: { autoplay: false },   // no pre-roll: never an ad before the first game
      onEvent(event) {
        switch (event && event.name) {
          case 'SDK_READY': ready(true); break;
          case 'SDK_ERROR': ready(false); break;
          case 'SDK_GAME_PAUSE':
            gdPaused = true;
            if (gdHooks) safe(() => gdHooks.beforeAd());
            else { call('pauseGame'); call('pauseAudio'); }   // an ad we didn't ask for: hold the game anyway
            break;
          case 'SDK_GAME_START':
            if (gdPaused) { gdPaused = false; if (gdHooks) safe(() => gdHooks.afterAd()); else call('resumeAudio'); }
            break;
          default: break;
        }
      },
    };
    if (!(await load(GD_SDK_URL, 'gamedistribution-jssdk'))) return;
    await withDeadline(gdReady, ms, false);
    live = !!win.gdsdk && typeof win.gdsdk.showAd === 'function';
  }
  async function gdMidgame(h) {
    const sdk = gd();
    if (!sdk) return false;
    gdHooks = h;
    let ok = false;
    try { await sdk.showAd(); ok = true; } catch (e) { ok = false; }
    if (gdPaused) { gdPaused = false; safe(() => h.afterAd()); }   // the SDK never said START: resume anyway
    gdHooks = null;
    return ok;
  }

  // --- Saves ------------------------------------------------------------------------------------------------------
  const data = () => {
    const d = safe(() => cg() && cg().data);
    return d && typeof d.getItem === 'function' && typeof d.setItem === 'function' ? d : null;
  };
  const ls = () => safe(() => win.localStorage) || null;

  function hold(on) {
    if (on && !blocker && doc && doc.body) {
      blocker = doc.createElement('div');
      blocker.className = 'hp-portal-busy';
      blocker.setAttribute('aria-busy', 'true');
      blocker.setAttribute('aria-label', 'Loading');
      blocker.appendChild(doc.createElement('i'));
      doc.body.appendChild(blocker);
    } else if (!on && blocker) { blocker.remove(); blocker = null; }
  }
  let lastMode = 'menu';
  function gameplay() {
    if (PLAY.has(lastMode) && !busy) { if (playing === true) return; playing = true; safe(() => cg() && cg().game.gameplayStart()); }
    else { if (playing !== true) return; playing = false; safe(() => cg() && cg().game.gameplayStop()); }
  }

  const api = {
    kind,
    get live() { return live; },
    get playing() { return playing === true; },
    get busy() { return busy; },
    get runs() { return runs; },
    async boot() {
      try {
        if (kind === 'crazygames') await initCG();
        else if (kind === 'gamedistribution') await initGD();
      } catch (e) { live = false; }
      api.loadingStart();
      // iOS keeps a page's audio suspended until a gesture: any touch or key outside an ad resumes it.
      const wake = () => { if (!busy) call('resumeAudio'); };
      if (doc && doc.addEventListener) for (const t of ['pointerup', 'touchend', 'keydown']) doc.addEventListener(t, wake, true);
      return live;
    },
    loadingStart() { if (loading) return; loading = 1; safe(() => cg() && cg().game.loadingStart()); },
    ready() { if (loading === 2) return; loading = 2; safe(() => cg() && cg().game.loadingStop()); },
    attach(h) { hooks = h || {}; },
    sync(mode) { lastMode = mode; gameplay(); },
    ran() { runs++; },
    /** Is a midgame ad due when the result sheet is left? */
    due() { return live && runs >= 2 && (!lastAt || now() - lastAt >= gap); },
    leave(go) {
      if (busy) return;
      if (!api.due()) { go(); return; }
      busy = true; lastAt = now();
      hold(true); gameplay();
      let done = false;
      const finish = () => { if (done) return; done = true; hold(false); busy = false; go(); };
      const h = { beforeAd: () => call('pauseAudio'), afterAd: () => call('resumeAudio') };
      Promise.resolve().then(() => (kind === 'crazygames' ? cgMidgame(h) : gdMidgame(h))).then(finish, finish);
    },
    muted() { return muteAudio; },
    getItem(k) {
      const d = data();
      if (d) { const v = safe(() => d.getItem(k)); if (v !== null && v !== undefined) return v; }
      const s = ls();
      return s ? s.getItem(k) : null;
    },
    setItem(k, v) {
      let ok = false;
      const d = data();
      if (d) ok = safe(() => { d.setItem(k, v); return true; }) || false;
      const s = ls();
      if (s) ok = safe(() => { s.setItem(k, v); return true; }) || ok;
      if (!ok) throw new Error('storage unavailable');
    },
  };
  return api;
}
