// The landing page's only script. CSS draws everything it can, and this adds what it can't:
// which section is near, the aurora itself, the parallax fallback, and the hand-off to the game.
(function () {
  'use strict';
  var root = document.documentElement;
  var calm = root.classList.contains('calm');
  var jsPar = root.classList.contains('js-par');
  var $ = function (s, el) { return (el || document).querySelector(s); };
  var $$ = function (s, el) { return Array.prototype.slice.call((el || document).querySelectorAll(s)); };
  var clamp = function (v, a, b) { return v < a ? a : v > b ? b : v; };

  var track = $('.arrive'), stage = $('.stage'), slot = $('.slot'), frame = $('#game');
  var doorA = $('.door-a'), doorB = $('.door-b');
  doorB.innerHTML = doorA.innerHTML;

  // ---- Near: only the sections around the viewport are promoted, drawn and animated.
  var nearIO = new IntersectionObserver(function (es) {
    es.forEach(function (e) { e.target.classList.toggle('near', e.isIntersecting); });
    if (jsPar) measure();
  }, { rootMargin: '60% 0px 60% 0px' });
  $$('.sec').forEach(function (s) { nearIO.observe(s); });

  // ---- The fallback driver and the track: one scroll listener, at most one update per frame.
  // Layout is read on resize and written to a cache, so the scroll path never forces a reflow.
  var vh = innerHeight, scopes = [], trackTop = 0, trackRun = 1;
  function measure() {
    vh = innerHeight;
    var y = scrollY;
    if (jsPar) {
      scopes = $$('.near, .near .own, .near .blk').map(function (el) {
        var r = el.getBoundingClientRect();
        return { el: el, top: r.top + y, h: r.height, own: el.classList.contains('own') };
      });
    }
    var t = track.getBoundingClientRect();
    trackTop = t.top + y;
    trackRun = Math.max(1, t.height - vh);
    measureSeam();
  }

  var ticking = false, lastY = scrollY, goingDown = true, idleTimer = 0, touching = false;
  function onScroll() {
    if (!ticking) { ticking = true; requestAnimationFrame(update); }
    clearTimeout(idleTimer);
    idleTimer = setTimeout(settle, 170);
  }
  function update() {
    ticking = false;
    var y = scrollY;
    if (y !== lastY) goingDown = y > lastY;
    lastY = y;
    if (jsPar) {
      for (var i = 0; i < scopes.length; i++) {
        var s = scopes[i], top = s.top - y;
        var p = s.own ? (vh - top) / (vh / 2 + s.h / 2) : (vh - top) / (vh + s.h);
        s.el.style.setProperty('--p', clamp(p, 0, 1).toFixed(4));
      }
    }
    onTrack(clamp((y - trackTop) / trackRun, 0, 1));
  }

  // ---- The track: the page parts, the game takes over, and the page gets it back on the way up.
  var inGame = false, frameLoaded = false, frameReady = false;
  var ENTER = 0.985, EXIT = 0.965;
  function tell(type) {
    if (frameReady) frame.contentWindow.postMessage({ hingepop: true, type: type }, location.origin);
  }
  function onTrack(p) {
    if (calm) return;
    if (jsPar) track.style.setProperty('--p', p.toFixed(4));
    root.classList.toggle('parting', p > 0.8);
    if (!inGame && p >= ENTER) setInGame(true);
    else if (inGame && p < EXIT) setInGame(false);
    // In the middle of the track the page owns the touch, or a finger on the frame would stop the scroll.
  }
  function setInGame(on) {
    inGame = on;
    root.classList.toggle('in-game', on);
    root.classList.toggle('hide-sky', on);
    if (field) { if (on) field.pause(); else field.play(); }
    tell(on ? 'enter' : 'leave');
  }
  // Lifted a finger part way through the parting? Finish it in the direction it was heading, so nobody is left
  // between the page and the game, and scrolling back up from the game never gets pushed back down.
  function settle() {
    if (touching || calm) return;
    var y = scrollY, p = (y - trackTop) / trackRun;
    if (p <= 0.001 || p >= 0.999) return;
    if (goingDown && p > 0.5) scrollTo({ top: trackTop + trackRun, behavior: 'smooth' });
    else if (!goingDown && p < 0.5) scrollTo({ top: trackTop, behavior: 'smooth' });
  }
  addEventListener('touchstart', function () { touching = true; }, { passive: true });
  addEventListener('touchend', function () { touching = false; idleTimer = setTimeout(settle, 170); }, { passive: true });

  // Load the frame when it is getting close. It sits there still and silent until it is told otherwise.
  function loadFrame() {
    if (frameLoaded) return;
    frameLoaded = true;
    frame.src = frame.dataset.src + (calm ? '?embed=static' : '?embed=scroll');
  }
  new IntersectionObserver(function (es) { if (es[0].isIntersecting) loadFrame(); }, { rootMargin: '150% 0px 150% 0px' }).observe(track);

  // Line the page's hinge up with wherever the game actually drew its own.
  var geo = null;
  function measureSeam() {
    var s = stage.getBoundingClientRect(), g = slot.getBoundingClientRect();
    var left = g.left - s.left, top = g.top - s.top;
    var vertical = geo ? geo.vertical : g.width > g.height;
    var hudGuess = 69;
    var pos = geo ? geo.pos : (vertical ? g.width / 2 : hudGuess + (g.height - hudGuess) / 2);
    stage.dataset.axis = vertical ? 'v' : 'h';
    stage.style.setProperty('--seam-y', (vertical ? 0 : top + pos) + 'px');
    stage.style.setProperty('--seam-x', (vertical ? left + pos : 0) + 'px');
    return { vertical: vertical, at: vertical ? left + pos : top + pos };
  }
  addEventListener('message', function (e) {
    if (e.origin !== location.origin || e.source !== frame.contentWindow || !e.data || !e.data.hingepop) return;
    if (e.data.type === 'ready') {
      frameReady = true;
      if (inGame) tell('enter');
      else if (calm && !isCalmGameVisible()) tell('leave');
    } else if (e.data.type === 'geometry') {
      geo = e.data;
      measureSeam();
      if (fieldReady && currentShape === 'seam') place('seam');
    }
  });

  // Reduced motion has no pin, so it pauses whenever the frame is out of view instead.
  var calmVisible = false;
  function isCalmGameVisible() { return calmVisible; }
  if (calm) {
    new IntersectionObserver(function (es) {
      calmVisible = es[0].isIntersecting;
      tell(calmVisible ? 'enter' : 'leave');
    }, { threshold: 0.5 }).observe(stage);
  }

  // ---- Ways in and out.
  function toGame() {
    // Long smooth scrolls run every layer through its whole range. Jump to the start of the track, then glide.
    scrollTo(0, Math.max(scrollY, trackTop));
    update();
    requestAnimationFrame(function () { scrollTo({ top: trackTop + trackRun, behavior: calm ? 'auto' : 'smooth' }); });
  }
  $$('[data-jump]').forEach(function (a) { a.addEventListener('click', function (e) { e.preventDefault(); toGame(); }); });
  $('.skip').addEventListener('click', function (e) { e.preventDefault(); toGame(); });
  $('#back-top').addEventListener('click', function () {
    scrollTo(0, 0);
    update();
    var cue = $('.hero .cue a');
    if (cue) cue.focus({ preventScroll: true });
  });

  addEventListener('scroll', onScroll, { passive: true });
  var resizeTimer = 0;
  addEventListener('resize', function () { clearTimeout(resizeTimer); resizeTimer = setTimeout(function () { measure(); onScroll(); }, 80); });
  if (window.ResizeObserver) new ResizeObserver(function () { measure(); onScroll(); }).observe(document.body);
  measure();
  update();

  // ---- Aurora curtains: painted once into small canvases and stretched, so the sky never repaints. Only their
  // opacity and transform ever change.
  var TINTS = {
    classic: [[51, 217, 255], [102, 115, 255], [64, 255, 191]],
    neon: [[230, 77, 255], [89, 128, 255], [255, 89, 179]],
    forest: [[77, 255, 140], [51, 217, 204], [191, 255, 89]],
    space: [[140, 89, 255], [51, 179, 255], [255, 115, 191]],
  };
  function paintCurtain(cv, cols, seed) {
    var g = cv.getContext('2d'), W = cv.width, H = cv.height;
    g.globalCompositeOperation = 'lighter';
    for (var band = 0; band < 3; band++) {
      var c = cols[band], base = H * (0.18 + band * 0.13), f1 = 0.011 + band * 0.004, f2 = 0.031 + band * 0.006;
      for (var x = 0; x < W; x++) {
        var wave = Math.sin(x * f1 + seed + band * 2.1) * H * 0.1 + Math.sin(x * f2 + seed * 1.7) * H * 0.04;
        var ray = 0.5 + 0.5 * Math.sin(x * 0.19 + band + seed) * Math.sin(x * 0.043 + seed * 2);
        var edge = Math.min(1, Math.min(x, W - x) / (W * 0.18));
        var a = (0.05 + 0.15 * ray) * edge, top = base + wave, len = H * (0.3 + 0.3 * ray);
        var grad = g.createLinearGradient(0, top - 6, 0, top + len);
        grad.addColorStop(0, 'rgba(' + c + ',0)');
        grad.addColorStop(0.16, 'rgba(' + c + ',' + a + ')');
        grad.addColorStop(0.55, 'rgba(' + c + ',' + a * 0.35 + ')');
        grad.addColorStop(1, 'rgba(' + c + ',0)');
        g.fillStyle = grad;
        g.fillRect(x, top - 6, 1, len + 6);
      }
    }
  }
  var curtains = {};
  $$('.curtain').forEach(function (el, i) {
    var tint = el.dataset.tint;
    curtains[tint] = el;
    paintCurtain($('canvas', el), TINTS[tint], i * 1.3 + 1);
  });
  function setTint(name) {
    Object.keys(curtains).forEach(function (k) { curtains[k].classList.toggle('on', k === name); });
  }
  setTint('neon');

  // ---- The aurora field: one field for the whole page, morphing as the page goes by.
  var field = null, fieldReady = false, currentShape = '';
  var cv = $('#field'), box = $('#field-box');
  var AF = window.AuroraField;
  var mkPal = function (a, b, fog) {
    return { point: a, accent: b, hot: '#FFFFFF', star: '#E6DCFF', signal: b, head: [255, 255, 255], glow: a, glow2: [60, 30, 140], fog: fog || [40, 24, 90] };
  };
  var PAL = {
    logo: mkPal([79, 216, 255], [255, 199, 51]),
    classic: mkPal([79, 216, 255], [120, 255, 214]),
    neon: mkPal([240, 110, 255], [120, 150, 255]),
    forest: mkPal([110, 255, 160], [210, 255, 120]),
    space: mkPal([170, 130, 255], [90, 200, 255]),
    hot: mkPal([255, 170, 80], [255, 110, 190]),
  };
  // x and y shift the field off centre (vw, vh), wide screens and narrow ones. The field stays clear of the words.
  var SHAPES = {
    logo: { wide: [0, -6, 1.06, 1], narrow: [0, -9, 1.06, 1], pal: 'logo', tint: 'neon' },
    hinge: { wide: [0, 2, 1, 1], narrow: [0, 2, 1, 1], pal: 'classic', tint: 'classic' },
    burst: { wide: [-22, 0, 1, 1.00], narrow: [14, -20, 0.8, 1.00], pal: 'classic', tint: 'classic' },
    slice: { wide: [-20, 0, 1, 1.00], narrow: [0, -20, 0.9, 1.00], pal: 'logo', tint: 'neon' },
    chain: { wide: [24, -2, 1, 1.00], narrow: [0, 24, 0.8, 1.00], pal: 'neon', tint: 'neon' },
    bubble: { wide: [0, 0, 1.3, 0.85], narrow: [0, 0, 1.15, 0.77], pal: 'neon', tint: 'neon' },
    star: { wide: [22, -8, 1.15, 1.00], narrow: [24, -24, 0.9, 1.00], pal: 'logo', tint: 'space' },
    num1: { wide: [24, 0, 1.25, 1], narrow: [0, -24, 0.95, 1], pal: 'classic', tint: 'classic' },
    num2: { wide: [-24, 0, 1.25, 1], narrow: [0, -24, 0.95, 1], pal: 'neon', tint: 'neon' },
    num3: { wide: [24, 0, 1.25, 1], narrow: [0, -24, 0.95, 1], pal: 'forest', tint: 'forest' },
    num4: { wide: [-24, 0, 1.25, 1], narrow: [0, -24, 0.95, 1], pal: 'space', tint: 'space' },
    num5: { wide: [24, 0, 1.25, 1], narrow: [0, -24, 0.95, 1], pal: 'neon', tint: 'neon' },
    infinity: { wide: [-22, 0, 1.2, 1], narrow: [0, -24, 0.9, 1], pal: 'space', tint: 'space' },
    two: { wide: [0, -6, 1.2, 0.85], narrow: [0, -14, 1, 0.77], pal: 'hot', tint: 'classic' },
    duo: { wide: [24, 8, 1, 0.77], narrow: [24, -8, 0.8, 0.51], pal: 'classic', tint: 'neon' },
    'logo-app': { wide: [26, -14, 0.8, 0.77], narrow: [0, -26, 0.8, 0.48], pal: 'logo', tint: 'classic' },
    seam: { wide: [0, 0, 1, 1], narrow: [0, 0, 1, 1], pal: 'classic', tint: 'classic' },
  };
  function place(name) {
    var s = SHAPES[name], wide = innerWidth >= 900 && innerWidth > innerHeight, c = wide ? s.wide : s.narrow, x = c[0] / 100 * innerWidth, y = c[1] / 100 * innerHeight;
    if (name === 'seam') {
      var seam = measureSeam();
      if (seam.vertical) x = seam.at - innerWidth / 2; else y = seam.at - cv.clientHeight / 2;
    }
    box.style.transform = 'translate3d(' + x.toFixed(1) + 'px,' + y.toFixed(1) + 'px,0) scale(' + c[2] + ')';
    box.style.opacity = c[3];
  }
  function showShape(name) {
    if (!fieldReady || name === currentShape || !SHAPES[name]) return;
    currentShape = name;
    var s = SHAPES[name], shape = 'hp-' + (name === 'logo-app' ? 'logo' : name === 'seam' ? (stage.dataset.axis === 'v' ? 'seam-v' : 'seam-h') : name);
    field.setShape(shape);
    field.set({ palette: PAL[s.pal] });
    place(name);
  }

  function radiusOf(w, h) { return Math.max(110, Math.min(w * 0.4, h * 0.3, 340)); }
  function build() {
    var W = innerWidth, H = cv.clientHeight || innerHeight, R = radiusOf(W, H), TAU = Math.PI * 2;
    var ring = function (cx, cy, rad, rnd, thick) { var a = rnd() * TAU, r = rad + (rnd() - 0.5) * (thick || 0.03); return [cx + Math.cos(a) * r, cy + Math.sin(a) * r, (rnd() - 0.5) * 0.12]; };
    var reg = function (name, fn, extra) {
      AF.register(name, function (n, rnd) {
        var pts = [], tone = [];
        for (var i = 0; i < n; i++) { var p = fn(i / n, rnd, i); tone.push(p[3] || 0); pts.push([p[0], p[1], p[2]]); }
        var out = { points: pts, tone: tone, facing: true, kick: 0.4 };
        if (extra) extra(out);
        return out;
      });
    };
    // The hinge: a line across the whole screen that crackles like the real one.
    var hingeShape = function (name, vertical) {
      var span = ((vertical ? H : W) / 2) / R * 1.08;
      AF.register(name, function (n, rnd) {
        var pts = [], tone = [], off = [];
        for (var i = 0; i < n; i++) {
          var u = (i / n) * 2 - 1, a = u * span, b = (rnd() - 0.5) * 0.05;
          off.push(a);
          pts.push(vertical ? [b, a, (rnd() - 0.5) * 0.04] : [a, b, (rnd() - 0.5) * 0.04]);
          tone.push(rnd() < 0.2 ? 1 : 0);
        }
        return {
          points: pts, tone: tone, facing: true, kick: 0.2,
          flow: function (i, t) {
            var a = off[i], w = Math.sin(a * 9 + t * 5) * 0.03 * Math.sin(a * 2.3 - t * 2.7) + Math.sin(a * 23 + t * 11) * 0.012;
            return vertical ? [pts[i][0] + w, a, pts[i][2]] : [a, pts[i][1] + w, pts[i][2]];
          },
        };
      });
    };
    hingeShape('hp-hinge', false);
    hingeShape('hp-seam-h', false);
    hingeShape('hp-seam-v', true);
    reg('hp-bubble', function (u, r) {
      if (u < 0.6) { var a = r() * TAU, sz = 1 + (r() - 0.5) * 0.05; return [Math.cos(a) * sz, Math.sin(a) * sz, (r() - 0.5) * 0.2]; }
      if (u < 0.82) { var left = u < 0.71, ea = r() * TAU, er = Math.sqrt(r()); return [(left ? -0.34 : 0.34) + Math.cos(ea) * er * 0.17, -0.14 + Math.sin(ea) * er * 0.25, -0.1, 1]; }
      var m = r() * Math.PI; return [Math.cos(m) * 0.42, 0.22 + Math.sin(m) * 0.32 * r(), -0.1, 1];
    });
    reg('hp-burst', function (u, r) {
      if (u < 0.45) return ring(0, 0, 0.55, r);
      var a = Math.floor(r() * 10) / 10 * TAU, d = 0.78 + r() * 0.5;
      return [Math.cos(a) * d, Math.sin(a) * d, (r() - 0.5) * 0.1, 1];
    });
    reg('hp-slice', function (u, r) {
      if (u < 0.5) { var t = r() * 2 - 1; return [t * 1.5, -t * 0.95 + (r() - 0.5) * 0.04, 0, 1]; }
      var side = u < 0.75 ? -1 : 1, a = r() * TAU;
      return [side * 0.42 + side * 0.08 + Math.cos(a) * 0.4, side * 0.42 + Math.sin(a) * 0.4, (r() - 0.5) * 0.14];
    });
    var knots = [[-0.8, 0.3, 0.22], [-0.36, -0.42, 0.28], [0.1, 0.22, 0.2], [0.42, -0.5, 0.18], [0.78, 0.12, 0.3], [-0.2, 0.74, 0.16], [0.42, 0.74, 0.14]];
    reg('hp-chain', function (u, r) { var k = knots[Math.floor(u * knots.length)]; return ring(k[0], k[1], k[2], r); });
    reg('hp-star', function (u, r) {
      var a = r() * TAU, s = 0.14 + 1.1 * Math.pow(Math.abs(Math.cos(a * 2)), 7), f = u < 0.55 ? 1 : Math.sqrt(r());
      return [Math.cos(a) * s * f, Math.sin(a) * s * f, (r() - 0.5) * 0.1, u < 0.55 ? 0 : 1];
    });
    reg('hp-infinity', function (u, r) {
      var a = r() * TAU, d = 1 + Math.sin(a) * Math.sin(a), j = (r() - 0.5) * 0.09;
      return [1.3 * Math.cos(a) / d + j, 1.3 * Math.sin(a) * Math.cos(a) / d + (r() - 0.5) * 0.09, (r() - 0.5) * 0.14, r() < 0.2 ? 1 : 0];
    });
    reg('hp-two', function (u, r) {
      if (u < 0.2) return [(r() - 0.5) * 0.03, r() * 2.2 - 1.1, 0, 1];
      return ring(u < 0.6 ? -0.74 : 0.74, 0, 0.52, r);
    });
    reg('hp-duo', function (u, r) {
      var w = 0.88, h = 1;
      if (u < 0.2) return [(r() - 0.5) * 0.03, r() * 2 * h - h, 0, 1];
      var t = r() * (4 * w + 4 * h);
      if (t < 2 * w) return [t - w, -h, 0];
      if (t < 2 * w + 2 * h) return [w, t - 2 * w - h, 0];
      if (t < 4 * w + 2 * h) return [t - 2 * w - 2 * h - w, h, 0];
      return [-w, t - 4 * w - 2 * h - h, 0];
    });
    // Numbers in the page's own type.
    ['1', '2', '3', '4', '5'].forEach(function (n) {
      AF.register('hp-num' + n, AF.fromText(n, { font: '400 180px "Titan One", sans-serif', threshold: 0.5, depth: 0.1 }));
    });
  }
  // The logo in particles: gold for POP, blue for HINGE. Tone follows brightness, so the mask is painted for it.
  function logoMask(img) {
    var w = 340, h = Math.round(w * img.naturalHeight / img.naturalWidth), c = document.createElement('canvas');
    c.width = w; c.height = h;
    var g = c.getContext('2d');
    g.drawImage(img, 0, 0, w, h);
    var data = g.getImageData(0, 0, w, h), d = data.data;
    for (var i = 0; i < d.length; i += 4) {
      var r = d[i], gr = d[i + 1], b = d[i + 2], a = d[i + 3];
      var gold = a > 200 && r > 200 && gr > 130 && b < 170, blue = a > 200 && b > 190 && gr > 110 && r < 190;
      var v = gold ? 255 : blue ? 42 : 0;
      d[i] = d[i + 1] = d[i + 2] = v;
      d[i + 3] = 255;
    }
    return data;
  }
  function startField() {
    if (!AF) return;
    var img = $('.hero-logo img');
    var go = function () {
      if (field) return;
      try {
        build();
        AF.register('hp-logo', AF.fromImage(logoMask(img), { threshold: 0.1, tone: 'luma', edges: 0.5, depth: 0.08 }));
        var narrow = innerWidth < 760;
        field = AF.create(cv, {
          container: box,
          shapes: Object.keys(SHAPES).filter(function (k) { return k !== 'logo-app' && k !== 'seam'; }).map(function (k) { return 'hp-' + k; }).concat(['hp-seam-h', 'hp-seam-v']),
          rotation: ['hp-logo'], initial: 'hp-logo', cycle: 0, intro: 900, seed: 7, count: narrow ? 3000 : 5600, stars: narrow ? 0 : 40,
          autonomy: 0.4, depth: 3.2, interactive: !narrow && matchMedia('(hover: hover)').matches, palette: PAL.logo, radius: radiusOf, maxDpr: narrow ? 2 : 1.75,
        });
        fieldReady = true;
        root.classList.add('has-field');
        currentShape = 'logo';
        place('logo');
        if (!calm) {
          field.prepare();
          if (pendingShape) showShape(pendingShape);
          if (inGame) field.pause();
          if (matchMedia('(hover: hover)').matches) {
            addEventListener('pointermove', function (e) {
              if (e.pointerType !== 'mouse') return;
              field.pointer('move', e.clientX, e.clientY);
            }, { passive: true });
          }
        }
      } catch (err) {
        // The page reads fine without its aurora. Tell developers, and carry on.
        console.warn('aurora-field did not start', err);
      }
    };
    var fontReady = document.fonts && document.fonts.load ? document.fonts.load('400 180px "Titan One"', '12345') : Promise.resolve();
    var imgReady = img.complete && img.naturalWidth ? Promise.resolve() : new Promise(function (ok) { img.addEventListener('load', ok, { once: true }); });
    Promise.all([fontReady.catch(function () {}), imgReady]).then(go);
  }

  // Whatever crosses the middle of the screen sets the shape and the sky.
  var pendingShape = '';
  if (!calm) {
    var shapeIO = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (!e.isIntersecting) return;
        var name = e.target.dataset.shape;
        pendingShape = name;
        var tint = e.target.dataset.tint || (SHAPES[name] && SHAPES[name].tint);
        if (tint) setTint(tint);
        showShape(name);
      });
    }, { rootMargin: '-50% 0px -50% 0px' });
    $$('[data-shape]').forEach(function (s) { shapeIO.observe(s); });
  }
  startField();

  // A little hook for the tests, and nothing else.
  window.hingePopPage = {
    get inGame() { return inGame; },
    get frameReady() { return frameReady; },
    get shape() { return currentShape; },
    get seam() { return measureSeam(); },
    get trackEnd() { return trackTop + trackRun; },
    get field() { return field; },
  };
})();
