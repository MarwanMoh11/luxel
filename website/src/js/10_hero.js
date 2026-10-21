/* The hero: the game's title screen (scripts/game/screens/title.gd) over the real island. It opens dark; LUXEL's
   luxels light west to east and their light shows the grove, then spills over it. Fireflies drift up and join
   the letters, and the cursor carries a lantern that warms what it passes. */
(function () {
  "use strict";
  var Lux = window.Lux, P = Lux.PAL;
  var hero = document.getElementById("hero-canvas");
  if (!hero) return;
  var ctx = hero.getContext("2d");
  var MAP_SRC = hero.getAttribute("data-map") || "assets/img/island.png";
  var FRAME_X = 260;          /* the title camera's centre x on the island (title.gd FRAMING) */
  var GAP = 0.04, FLASH = 0.08, REACH = 64, GROW = 0.8, SPILL_AFTER = 0.3, SPILL = 1.4, LIGHT_AT = 0.45;
  var W = 0, H = 0, S = 2, map = null, bufs = null, level = null, img = null, out32 = null;
  var cells = [], litAt = [], flashTo = [], t = 0, visible = true, done = false, lastLight = 0;
  var flies = [], drift = [], nextFly = 2, mouse = null, prevMouse = null, typed = false;
  var touch = !window.matchMedia || window.matchMedia("(hover: none)").matches;

  function nearestFactory() {
    var keys = Object.keys(Lux.RGB), cache = new Map();
    return function (r, g, b) {
      var k = (r << 16) | (g << 8) | b, v = cache.get(k);
      if (v !== undefined) return v;
      var best = 0, bd = 1e9;
      for (var i = 0; i < keys.length; i++) {
        var c = Lux.RGB[keys[i]], dr = c[0] - r, dg = c[1] - g, db = c[2] - b;
        var d = dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11;
        if (d < bd) { bd = d; best = i; }
      }
      var cc = Lux.RGB[keys[best]];
      v = (255 << 24) | (cc[2] << 16) | (cc[1] << 8) | cc[0];
      cache.set(k, v);
      return v;
    };
  }
  var nearest = nearestFactory();

  function size() {
    var rect = hero.parentNode.getBoundingClientRect();
    var cw = Math.ceil(rect.width), ch = Math.ceil(rect.height);
    S = Math.max(2, Math.min(6, Math.floor(cw / 230)));
    W = Math.ceil(cw / S); H = Math.ceil(ch / S);
    hero.width = W; hero.height = H;
    hero.style.width = W * S + "px"; hero.style.height = H * S + "px";
    img = ctx.createImageData(W, H);
    out32 = new Uint32Array(img.data.buffer);
    level = new Float32Array(W * H);
    var ox = Math.round(W / 2 - (19 * 5) / 2);
    var oy = Math.max(7, Math.min(Math.round(H * 0.07), 28));
    cells = Lux.luxelCells("LUXEL", ox, oy, 5);
    litAt = cells.map(function (c, i) { return LIGHT_AT + i * GAP; });
    flashTo = cells.map(function () { return -1; });
    lastLight = litAt[litAt.length - 1];
    buildBuffers();
    drift = [];
    var rnd = Lux.rng(7);
    for (var i = 0; i < Math.round(W * H / 2600) + 6; i++) {
      drift.push({ x: rnd() * W, y: H * 0.35 + rnd() * H * 0.65, p: rnd() * 6.28, sp: 0.3 + rnd() * 0.6 });
    }
    if (Lux.reduced) t = 99;
    dirtyAll = true;
  }

  /* Four versions of the island crop: dark (the night), mid, lit and warm (under a lantern). */
  function buildBuffers() {
    var n = W * H;
    bufs = [new Uint32Array(n), new Uint32Array(n), new Uint32Array(n), new Uint32Array(n)];
    var src = null, sw = 0, sh = 0, sx = 0;
    if (map) {
      sw = map.width; sh = map.height;
      sx = Math.max(0, Math.min(sw - W, Math.round(FRAME_X - W / 2)));
      src = map.data;
    }
    var v = Lux.RGB.void, ap = Lux.RGB.apricot;
    var rnd = Lux.rng(3);
    for (var y = 0; y < H; y++) {
      for (var x = 0; x < W; x++) {
        var i = y * W + x, r, g, b;
        var mx = x + sx, my = y;
        if (src && mx < sw && my < sh) {
          var j = (my * sw + mx) * 4;
          r = src[j]; g = src[j + 1]; b = src[j + 2];
        } else {
          r = v[0]; g = v[1]; b = v[2];
          if (rnd() < 0.006) { var st = Lux.RGB[rnd() < 0.5 ? "stone" : "ice"]; r = st[0]; g = st[1]; b = st[2]; }
        }
        bufs[2][i] = (255 << 24) | (b << 16) | (g << 8) | r;
        bufs[0][i] = nearest(Math.round(r * 0.18 + v[0] * 0.82), Math.round(g * 0.18 + v[1] * 0.82), Math.round(b * 0.18 + v[2] * 0.82));
        bufs[1][i] = nearest(Math.round(r * 0.5 + v[0] * 0.5), Math.round(g * 0.5 + v[1] * 0.5), Math.round(b * 0.5 + v[2] * 0.5));
        bufs[3][i] = nearest(Math.round(r * 0.7 + ap[0] * 0.3), Math.round(g * 0.7 + ap[1] * 0.3), Math.round(b * 0.7 + ap[2] * 0.3));
      }
    }
  }

  var BAYER = [0.125, 0.625, 0.875, 0.375];
  var dirtyAll = true;

  /* The light at (x, y): 0 dark, 1 mid, 2 lit, 3 warm, continuous. */
  function staticLight(x, y) {
    var v = 0;
    var spill = (t - lastLight - SPILL_AFTER) / SPILL;
    if (spill > 0) {
      var cx = W / 2, cy = cells.length ? cells[0].y + 12 : 20;
      var far = Math.sqrt(Math.max(cx * cx, (W - cx) * (W - cx)) + (H - cy) * (H - cy) + cy * cy);
      var rr = Math.min(1, spill) * far * 1.15;
      var d = Math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy));
      v = Math.max(v, Math.min(2, (rr - d) / 10 + 1));
      /* the title keeps warming the sky around it */
    }
    for (var L = 0; L < 5; L++) {
      var c = letterLight[L];
      if (!c || c.r <= 0) continue;
      var dx = x - c.x, dy = (y - c.y) * 1.25, dd = Math.sqrt(dx * dx + dy * dy);
      var lv = (c.r - dd) / (c.r * 0.22);
      if (lv > 0) v = Math.max(v, Math.min(3, lv));
    }
    return v;
  }
  var letterLight = [];
  function updateLetters() {
    letterLight = [];
    for (var L = 0; L < 5; L++) {
      var first = -1, sx = 0, sy = 0, n = 0;
      for (var i = 0; i < cells.length; i++) if (cells[i].letter === L) {
        if (first < 0) first = litAt[i];
        sx += cells[i].x + 2; sy += cells[i].y + 2; n++;
      }
      if (!n) continue;
      var k = Math.max(0, Math.min(1, (t - first) / GROW));
      var base = REACH * (1 - Math.pow(1 - k, 2));
      letterLight[L] = { x: sx / n, y: sy / n, r: base };
    }
  }

  function cursorLight(x, y) {
    if (!mouse) return 0;
    var dx = x - mouse.x, dy = y - mouse.y, d = Math.sqrt(dx * dx + dy * dy), R = 30;
    return d < R ? Math.min(1, (R - d) / 9) : 0;
  }

  function compose(x0, y0, x1, y1, recompute) {
    x0 = Math.max(0, x0 | 0); y0 = Math.max(0, y0 | 0); x1 = Math.min(W, Math.ceil(x1)); y1 = Math.min(H, Math.ceil(y1));
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        var i = y * W + x;
        if (recompute) level[i] = staticLight(x, y);
        var v = level[i] + cursorLight(x, y);
        var q = Math.floor(v + BAYER[(y & 1) * 2 + (x & 1)]);
        q = q < 0 ? 0 : q > 3 ? 3 : q;
        out32[i] = bufs[q][i];
      }
    }
  }

  function luxelState(i) {
    if (t < litAt[i]) return t > litAt[i] - 0.25 ? "unlit" : null;
    if (t < litAt[i] + FLASH) return "flash";
    if (flashTo[i] > t) return "flash";
    var step = Math.floor(t / 0.14), h = Lux.hash(i, step);
    return h < 0.05 ? "dim" : "lit";
  }

  function spawnFly() {
    var target = Math.floor(Math.random() * cells.length);
    var fx = W * (0.15 + Math.random() * 0.7), fy = H * (0.6 + Math.random() * 0.35);
    flies.push({ x0: fx, y0: fy, i: target, t0: t, bow: (Math.random() - 0.5) * 80 });
  }

  function drawFly(x, y, on) {
    x = Math.round(x); y = Math.round(y);
    ctx.fillStyle = P.wine; ctx.fillRect(x - 1, y, 3, 1); ctx.fillRect(x, y - 1, 1, 3);
    ctx.fillStyle = on ? P.gold : P.apricot; ctx.fillRect(x, y, 1, 1);
  }

  var lastMouseBox = null;
  function frame(dt) {
    if (!visible || !bufs) return;
    t += dt;
    var lighting = t < lastLight + SPILL_AFTER + SPILL + GROW + 0.1;
    updateLetters();
    if (lighting || dirtyAll) {
      compose(0, 0, W, H, true);
      dirtyAll = false;
      lastMouseBox = null;
    } else if (mouse !== prevMouse || (mouse && prevMouse && (mouse.x !== prevMouse.x || mouse.y !== prevMouse.y))) {
      var R = 32;
      if (lastMouseBox) compose(lastMouseBox[0], lastMouseBox[1], lastMouseBox[2], lastMouseBox[3], false);
      if (mouse) { lastMouseBox = [mouse.x - R, mouse.y - R, mouse.x + R + 1, mouse.y + R + 1]; compose(lastMouseBox[0], lastMouseBox[1], lastMouseBox[2], lastMouseBox[3], false); }
      else lastMouseBox = null;
      prevMouse = mouse ? { x: mouse.x, y: mouse.y } : null;
    }
    ctx.putImageData(img, 0, 0);
    /* drifting fireflies over the grove, once it is lit */
    if (t > lastLight) {
      for (var k = 0; k < drift.length; k++) {
        var f = drift[k];
        f.p += dt * f.sp;
        var x = f.x + Math.sin(f.p * 1.3) * 6, y = f.y + Math.sin(f.p) * 4 - (t % 40) * 0.02;
        if (Math.sin(f.p * 2.1 + k) > -0.2) drawFly(x, y, Math.sin(f.p * 3 + k) > 0.6);
      }
    }
    /* fireflies that fly up and join the letters */
    if (!Lux.reduced && t > lastLight + SPILL_AFTER + SPILL) {
      nextFly -= dt;
      if (nextFly <= 0) { spawnFly(); nextFly = 2.5 + Math.random() * 2; }
    }
    for (var m = flies.length - 1; m >= 0; m--) {
      var fl = flies[m], k2 = (t - fl.t0) / 1.8, c = cells[fl.i];
      if (k2 >= 1) { flashTo[fl.i] = t + 0.2; flies.splice(m, 1); continue; }
      var e = k2 * k2 * (3 - 2 * k2), tx = c.x + 2, ty = c.y + 2;
      var bx = (fl.x0 + tx) / 2 + fl.bow, by = (fl.y0 + ty) / 2;
      var px = (1 - e) * (1 - e) * fl.x0 + 2 * (1 - e) * e * bx + e * e * tx;
      var py = (1 - e) * (1 - e) * fl.y0 + 2 * (1 - e) * e * by + e * e * ty;
      drawFly(px, py, true);
    }
    for (var i = 0; i < cells.length; i++) {
      var st = luxelState(i);
      if (st) Lux.drawLuxel(ctx, cells[i].x, cells[i].y, st, 4);
      if (!typed && st && t >= litAt[i] && t - dt < litAt[i] && heard) Lux.note(Lux.CHORD[cells[i].row], 0.9, 0.12);
    }
    if (!typed && t > lastLight + 0.35) { typed = true; typeTagline(); }
  }

  /* The lantern notes play only if the reader has already clicked or pressed something on the page. */
  var heard = false;
  ["pointerdown", "keydown"].forEach(function (ev) { window.addEventListener(ev, function () { heard = true; }, { once: true }); });

  function typeTagline() {
    var p = document.querySelector(".tagline[data-type]");
    if (!p || Lux.reduced) { if (p) p.classList.add("typed"); return; }
    var spans = Lux.$$(".t", p), full = spans.map(function (s) { return s.textContent; });
    p.setAttribute("aria-label", full.join(" "));
    spans.forEach(function (s) { s.setAttribute("aria-hidden", "true"); s.textContent = " "; });
    var line = 0, ch = 0;
    function step() {
      if (line >= spans.length) return;
      ch++;
      spans[line].textContent = Lux.say(full[line].slice(0, ch)) || " ";
      if (ch >= full[line].length) { line++; ch = 0; setTimeout(step, 380); }
      else setTimeout(step, 26);
    }
    step();
  }

  /* After DISPLAY: OFF the lantern bursts the page back and the title lights again. */
  Lux.heroRelight = function () { if (Lux.reduced) return; t = 0; flies = []; dirtyAll = true; };

  hero.parentNode.addEventListener("pointermove", function (e) {
    if (e.pointerType !== "mouse") return;
    Lux.overHero = true; /* the hero carries its own lantern, drawn in the palette */
    var r = hero.getBoundingClientRect();
    mouse = { x: Math.round((e.clientX - r.left) / S), y: Math.round((e.clientY - r.top) / S) };
  });
  hero.parentNode.addEventListener("pointerleave", function () { mouse = null; Lux.overHero = false; });

  function start() {
    size();
    Lux.onFrame(frame);
    Lux.watch(hero.parentNode, function (v) { visible = v; }, "0px");
    var rt = 0;
    window.addEventListener("resize", function () {
      clearTimeout(rt);
      rt = setTimeout(function () {
        var keep = t; size(); t = Math.max(keep, lastLight + 4); dirtyAll = true;
      }, 150);
    });
  }

  var im = new Image();
  im.onload = function () {
    var c = document.createElement("canvas");
    c.width = im.naturalWidth; c.height = im.naturalHeight;
    var cx = c.getContext("2d");
    cx.drawImage(im, 0, 0);
    try { map = cx.getImageData(0, 0, c.width, c.height); } catch (e) { map = null; }
    start();
  };
  im.onerror = start;
  im.src = MAP_SRC;

  /* The small luxel logo in the top bar. */
  Lux.ready(function () {
    var b = document.getElementById("brand-canvas");
    if (!b) return;
    b.width = 19 * 5 + 1; b.height = 26;
    b.style.width = b.width + "px"; b.style.height = b.height + "px";
    var bx = b.getContext("2d"), cs = Lux.luxelCells("LUXEL", 1, 1, 5), bt = 0;
    function draw(dt) {
      bt += dt;
      bx.clearRect(0, 0, b.width, b.height);
      for (var i = 0; i < cs.length; i++) {
        var h = Lux.hash(i + 100, Math.floor(bt / 0.14));
        Lux.drawLuxel(bx, cs[i].x, cs[i].y, h < 0.04 ? "dim" : "lit", 4);
      }
    }
    draw(0);
    if (!Lux.reduced) { var acc = 0; Lux.onFrame(function (dt) { acc += dt; if (acc > 0.14) { acc = 0; draw(0.14); } }); }
  });
})();
