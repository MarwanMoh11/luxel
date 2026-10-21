/* Luxel site core: palette, the 3x5 font on canvas, one frame loop, storage, sound, small helpers. */
(function () {
  "use strict";
  var Lux = (window.Lux = {});
  Lux.PAL = {
    void: "#0d0b1e", night: "#211a3b", dusk: "#3d2c5c", plum: "#6a3d6f", wine: "#a0466a", coral: "#e2725b",
    apricot: "#f5a96a", gold: "#ffd98c", cream: "#fff4dc", pine: "#1d3d4c", teal: "#2b6b68", jade: "#4c9e78",
    lime: "#a3cf7d", deep: "#263873", blue: "#3e6db0", sky: "#78a9da", ice: "#c7e5ef", mauve: "#8a6e91",
    stone: "#c2a7ae", rose: "#ec9fa8"
  };
  Lux.RGB = {};
  Object.keys(Lux.PAL).forEach(function (k) {
    var h = Lux.PAL[k];
    Lux.RGB[k] = [parseInt(h.substr(1, 2), 16), parseInt(h.substr(3, 2), 16), parseInt(h.substr(5, 2), 16)];
  });
  Lux.reduced = window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  Lux.data = {};
  try { Lux.data = JSON.parse(document.getElementById("site-data").textContent); } catch (e) { Lux.data = {}; }
  Lux.$ = function (s, root) { return (root || document).querySelector(s); };
  Lux.$$ = function (s, root) { return Array.prototype.slice.call((root || document).querySelectorAll(s)); };

  /* Storage that never throws (private windows, blocked storage). */
  Lux.store = {
    get: function (k, d) { try { var v = localStorage.getItem("luxel." + k); return v === null ? d : JSON.parse(v); } catch (e) { return d; } },
    set: function (k, v) { try { localStorage.setItem("luxel." + k, JSON.stringify(v)); } catch (e) { /* no storage */ } }
  };

  /* Seeded random, for stable layouts. */
  Lux.rng = function (seed) {
    var s = seed >>> 0 || 1;
    return function () { s ^= s << 13; s >>>= 0; s ^= s >> 17; s ^= s << 5; s >>>= 0; return (s % 100000) / 100000; };
  };
  Lux.hash = function (a, b) {
    var h = (a * 374761393 + b * 668265263) | 0;
    h = (h ^ (h >>> 13)) * 1274126177 | 0;
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  };

  /* ---- The 3x5 font on canvas (PixelFont.draw: glyphs with a dark outline) ---- */
  var G = window.LUX_GLYPHS || {}, AL = window.LUX_ALIAS || {};
  Lux.glyph = function (ch) {
    var u = ch.toUpperCase();
    if (ch === "x") u = "X";
    if (G[u]) return G[u];
    if (AL[ch] && G[AL[ch]]) return G[AL[ch]];
    return null;
  };
  Lux.textWidth = function (text, s) { return Math.max(text.length * 4 - 1, 0) * (s || 1); };
  function glyphs(ctx, text, x, y, color, s) {
    ctx.fillStyle = color;
    for (var i = 0; i < text.length; i++) {
      var g = Lux.glyph(text[i]);
      if (!g) continue;
      for (var r = 0; r < 5; r++) {
        var bits = g[r];
        for (var c = 0; c < 3; c++) if (bits & (4 >> c)) ctx.fillRect(x + (i * 4 + c) * s, y + r * s, s, s);
      }
    }
  }
  Lux.drawText = function (ctx, text, x, y, color, outline, s) {
    s = s || 1;
    x = Math.round(x); y = Math.round(y);
    if (outline) {
      [[-1, 0], [1, 0], [0, -1], [0, 1], [1, 1]].forEach(function (o) { glyphs(ctx, text, x + o[0] * s, y + o[1] * s, outline, s); });
    }
    glyphs(ctx, text, x, y, color, s);
  };
  Lux.drawCentered = function (ctx, text, cx, y, color, outline, s) {
    Lux.drawText(ctx, text, Math.round(cx - Lux.textWidth(text, s) / 2), y, color, outline, s);
  };

  /* ---- Luxels (scripts/game/ui/luxels.gd): one per lit font pixel, a 4 px lamp on a 5 px grid ---- */
  Lux.LOOKS = {
    unlit: ["dusk", "plum", "night"], ember: ["coral", "apricot", "wine"], dim: ["apricot", "gold", "coral"],
    lit: ["gold", "cream", "apricot"], flash: ["cream", "cream", "gold"]
  };
  Lux.luxelCells = function (text, ox, oy, cell) {
    cell = cell || 5;
    var out = [];
    for (var i = 0; i < text.length; i++) {
      var g = Lux.glyph(text[i]);
      if (!g) continue;
      for (var c = 0; c < 3; c++) for (var r = 0; r < 5; r++) {
        if (g[r] & (4 >> c)) out.push({ x: ox + (i * 4 + c) * cell, y: oy + r * cell, letter: i, row: r });
      }
    }
    return out;
  };
  Lux.drawLuxel = function (ctx, x, y, state, block) {
    block = block || 4;
    var L = Lux.LOOKS[state];
    if (!L) return;
    var P = Lux.PAL;
    ctx.fillStyle = P.night; ctx.fillRect(x - 1, y - 1, block + 2, block + 2);
    ctx.fillStyle = P[L[0]]; ctx.fillRect(x, y, block, block);
    ctx.fillStyle = P[L[2]]; ctx.fillRect(x + 1, y + block - 1, block - 1, 1); ctx.fillRect(x + block - 1, y + 1, 1, block - 1);
    ctx.fillStyle = P[L[1]]; ctx.fillRect(x, y, block - 1, 1); ctx.fillRect(x, y, 1, block - 1);
  };

  /* ---- One frame loop for every animated thing, honouring the sold settings ---- */
  var subs = [], last = 0, acc = 0;
  Lux.fps = 60;          /* FRAME RATE sale: 20 */
  Lux.frozen = false;    /* ANIMATIONS sale */
  Lux.onFrame = function (fn) { subs.push(fn); };
  function loop(t) {
    requestAnimationFrame(loop);
    var dt = Math.min(0.1, (t - last) / 1000 || 0);
    last = t;
    acc += dt;
    var step = 1 / Lux.fps;
    if (Lux.fps < 60 && acc < step) return;
    var d = Lux.fps < 60 ? step : acc;
    acc = Lux.fps < 60 ? acc % step : 0;
    if (Lux.frozen) d = 0;
    for (var i = 0; i < subs.length; i++) {
      try { subs[i](d, t / 1000); } catch (e) { if (window.console) console.error(e); subs.splice(i--, 1); }
    }
  }
  requestAnimationFrame(loop);

  /* True while an element is near the viewport (to skip drawing what nobody sees). */
  Lux.watch = function (el, cb, margin) {
    if (!("IntersectionObserver" in window)) { cb(true); return; }
    new IntersectionObserver(function (es) { es.forEach(function (e) { cb(e.isIntersecting); }); },
      { rootMargin: margin || "200px 0px" }).observe(el);
  };

  /* Integer scale for pixel art: widest k * natural width that fits. */
  Lux.fit = function (el, natural, avail, minK) {
    var k = Math.max(minK || 1, Math.floor(avail / natural));
    el.style.width = natural * k + "px";
    return k;
  };

  /* ---- Sound: lantern notes from WebAudio, only ever after a click or key ---- */
  var ac = null, master = null;
  Lux.soundOn = true;
  Lux.audio = function () {
    if (!Lux.soundOn) return null;
    if (!ac) {
      var C = window.AudioContext || window.webkitAudioContext;
      if (!C) return null;
      ac = new C();
      master = ac.createGain();
      master.gain.value = 0.22;
      master.connect(ac.destination);
    }
    if (ac.state === "suspended") ac.resume();
    return ac;
  };
  /* A small bell: the lantern note (MIDI number), like the game's lantern_74 strum. */
  Lux.note = function (midi, len, vol) {
    var a = Lux.audio();
    if (!a) return;
    var f = 440 * Math.pow(2, (midi - 69) / 12), t = a.currentTime;
    len = len || 1.2;
    [[1, 1], [2.0, 0.35], [3.01, 0.12], [4.2, 0.05]].forEach(function (h) {
      var o = a.createOscillator(), g = a.createGain();
      o.type = "sine";
      o.frequency.value = f * h[0];
      g.gain.setValueAtTime(0.0001, t);
      g.gain.exponentialRampToValueAtTime((vol || 0.5) * h[1], t + 0.006);
      g.gain.exponentialRampToValueAtTime(0.0001, t + len / h[0]);
      o.connect(g); g.connect(master);
      o.start(t); o.stop(t + len + 0.05);
    });
  };
  Lux.snuff = function () {
    var a = Lux.audio();
    if (!a) return;
    var t = a.currentTime, n = a.sampleRate * 0.12, b = a.createBuffer(1, n, a.sampleRate), d = b.getChannelData(0);
    for (var i = 0; i < n; i++) d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / n, 3);
    var s = a.createBufferSource(), f = a.createBiquadFilter(), g = a.createGain();
    s.buffer = b; f.type = "lowpass"; f.frequency.value = 900; g.gain.value = 0.5;
    s.connect(f); f.connect(g); g.connect(master); s.start(t);
  };
  Lux.CHORD = [86, 81, 77, 74, 69]; /* the title's D minor strum, by font row */

  /* ---- Toast (the game's HUD nag) ---- */
  var toastT = 0;
  Lux.toast = function (lines, ms) {
    var el = document.getElementById("toast");
    if (!el) return;
    var p = el.firstElementChild;
    p.innerHTML = "";
    (Array.isArray(lines) ? lines : [lines]).forEach(function (l, i) {
      var s = document.createElement("span");
      s.style.display = "block";
      s.className = i ? "stone" : "gold";
      s.textContent = Lux.say(l);
      p.appendChild(s);
    });
    el.classList.add("on");
    clearTimeout(toastT);
    toastT = setTimeout(function () { el.classList.remove("on"); }, ms || 2200);
  };

  /* LANGUAGE sale: text through the game's cipher. */
  Lux.CIPHER = "QZXJKVBPYGFWUMCLDHRSNIOATE";
  Lux.gibberish = false;
  Lux.say = function (s) {
    if (!Lux.gibberish) return s;
    return String(s).replace(/[A-Za-z]/g, function (c) {
      var u = c.toUpperCase(), o = Lux.CIPHER[u.charCodeAt(0) - 65];
      return c === u ? o : o.toLowerCase();
    });
  };

  Lux.ready = function (fn) {
    if (document.readyState !== "loading") setTimeout(fn, 0);
    else document.addEventListener("DOMContentLoaded", fn);
  };
  Lux.fmt = function (s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2); };
})();
