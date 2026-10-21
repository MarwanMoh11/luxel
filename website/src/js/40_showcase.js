/* The showcase widgets: integer-scaled pixel art, the cast on canvas, the island to drag around, the palette,
   before/after, the sound players and the run arc, the journey's lamps and the counters. */
(function () {
  "use strict";
  var Lux = window.Lux, P = Lux.PAL;

  /* ---- Pixel art at whole-number scales: data-base = the width of the art's own pixel grid ---- */
  function snapAll() {
    Lux.$$("[data-base]").forEach(function (el) {
      var base = +el.getAttribute("data-base"), w = +el.getAttribute("width") || 0;
      var box = el.parentNode.getBoundingClientRect().width - (el.closest(".card") ? 0 : 0);
      if (!base || !box) return;
      var k = Math.floor(box / base);
      if (k >= 1) { el.style.width = base * k + "px"; el.style.maxWidth = "100%"; }
      else { el.style.width = "100%"; }
      el.style.height = "auto";
      if (w && !el.style.aspectRatio) el.style.aspectRatio = w + " / " + (+el.getAttribute("height") || w);
    });
  }
  Lux.ready(function () {
    snapAll();
    var t = 0;
    window.addEventListener("resize", function () { clearTimeout(t); t = setTimeout(snapAll, 120); });
    Lux.$$("details").forEach(function (d) { d.addEventListener("toggle", function () { if (d.open) snapAll(); }); });
  });

  /* ---- The cast: sprite sheets played on canvas at integer scale ---- */
  Lux.ready(function () {
    Lux.$$("canvas[data-sheet]").forEach(function (c) {
      var fw = +c.dataset.fw, fh = +c.dataset.fh, n = +c.dataset.frames || 1;
      var ms = (c.dataset.ms || "100").split(",").map(Number);
      var k = window.innerWidth < 520 ? 2 : window.innerWidth < 760 ? 3 : 4, pad = 4;
      c.width = (fw + pad * 2); c.height = (fh + pad * 2);
      c.style.width = c.width * k + "px"; c.style.height = c.height * k + "px";
      var x = c.getContext("2d"), im = new Image(), f = 0, acc = 0, vis = false, ready = false;
      function draw() {
        x.fillStyle = P.night; x.fillRect(0, 0, c.width, c.height);
        x.fillStyle = P.dusk;
        for (var yy = 0; yy < c.height; yy += 2) for (var xx = (yy / 2) % 2 ? 1 : 0; xx < c.width; xx += 8) x.fillRect(xx, yy + c.height - 10, 1, 1);
        if (ready) x.drawImage(im, f * fw, 0, fw, fh, pad, pad, fw, fh);
      }
      im.onload = function () { ready = true; draw(); };
      Lux.watch(c, function (v) { vis = v; if (v && !im.src) im.src = c.dataset.sheet; });
      Lux.onFrame(function (dt) {
        if (!vis || !ready || Lux.reduced) return;
        acc += dt * 1000;
        var d = ms[f % ms.length] || 100;
        if (acc >= d) { acc -= d; if (acc > 500) acc = 0; f = (f + 1) % n; draw(); }
      });
    });
  });

  /* ---- The island: drag (or arrow keys) to look around, + and - to zoom ---- */
  Lux.ready(function () {
    Lux.$$("[data-island]").forEach(function (box) {
      var im = Lux.$("img", box), z = 1, x = 0, y = 0, drag = null, auto = !Lux.reduced, t0 = 0;
      function minZ() { return Math.max(1, Math.ceil(box.clientHeight / 720)); }
      function clamp() {
        var w = 1280 * z, h = 720 * z;
        x = Math.min(0, Math.max(box.clientWidth - w, x));
        y = Math.min(0, Math.max(box.clientHeight - h, y));
        if (w < box.clientWidth) x = Math.round((box.clientWidth - w) / 2);
        if (h < box.clientHeight) y = Math.round((box.clientHeight - h) / 2);
      }
      function place() { clamp(); im.style.width = 1280 * z + "px"; im.style.height = 720 * z + "px"; im.style.transform = "translate(" + Math.round(x) + "px," + Math.round(y) + "px)"; }
      function init() { z = Math.max(minZ(), window.innerWidth < 760 ? 1 : 2); x = -180 * z + box.clientWidth / 2; y = -120 * z + box.clientHeight / 2; place(); }
      init();
      window.addEventListener("resize", init);
      var vis = false;
      Lux.watch(box, function (v) { vis = v; });
      Lux.onFrame(function (dt) {
        if (!auto || !vis || drag) return;
        t0 += dt;
        x -= dt * 14; y += Math.sin(t0 * 0.2) * dt * 6;
        var w = 1280 * z;
        if (x <= box.clientWidth - w) auto = false;
        place();
      });
      box.addEventListener("pointerdown", function (e) { auto = false; drag = { x: e.clientX - x, y: e.clientY - y }; box.classList.add("drag"); box.setPointerCapture(e.pointerId); });
      box.addEventListener("pointermove", function (e) { if (!drag) return; x = e.clientX - drag.x; y = e.clientY - drag.y; place(); });
      box.addEventListener("pointerup", function () { drag = null; box.classList.remove("drag"); });
      box.addEventListener("keydown", function (e) {
        var d = { ArrowLeft: [40, 0], ArrowRight: [-40, 0], ArrowUp: [0, 40], ArrowDown: [0, -40] }[e.key];
        if (!d) return;
        auto = false; x += d[0]; y += d[1]; place(); e.preventDefault();
      });
      Lux.$$("[data-z]", box).forEach(function (b) {
        b.addEventListener("pointerdown", function (e) { e.stopPropagation(); });
        b.addEventListener("click", function (e) {
          e.stopPropagation(); auto = false;
          var cx = box.clientWidth / 2, cy = box.clientHeight / 2, old = z;
          z = Math.max(minZ(), Math.min(4, z + +b.dataset.z));
          x = cx - (cx - x) * z / old; y = cy - (cy - y) * z / old; place();
        });
      });
    });
  });

  /* ---- The palette ---- */
  Lux.ready(function () {
    var box = Lux.$("[data-swatches]");
    if (!box) return;
    var dark = { void: 1, night: 1, dusk: 1, plum: 1, pine: 1, deep: 1, teal: 1, wine: 1, blue: 1, mauve: 1, jade: 1 };
    Object.keys(P).forEach(function (k) {
      var b = document.createElement("button");
      b.type = "button"; b.className = "swatch"; b.style.background = P[k];
      b.setAttribute("aria-label", k + " " + P[k]);
      b.innerHTML = '<span style="color:' + (dark[k] ? P.cream : P.night) + '">' + k + "</span>";
      b.addEventListener("click", function () {
        try { navigator.clipboard.writeText(P[k]); } catch (e) { /* no clipboard */ }
        Lux.toast([k.toUpperCase() + " " + P[k].toUpperCase(), "COPIED."], 1400);
        Lux.note(Lux.CHORD[Object.keys(P).indexOf(k) % 5], 0.5, 0.06);
      });
      box.appendChild(b);
    });
  });

  /* ---- Before / after ---- */
  Lux.ready(function () {
    Lux.$$("[data-ba]").forEach(function (box) {
      var after = Lux.$(".after", box), h = Lux.$(".handle", box), k = 50, drag = false;
      function set(v) { k = Math.max(0, Math.min(100, v)); after.style.clipPath = "inset(0 0 0 " + k + "%)"; h.style.left = k + "%"; box.setAttribute("aria-valuenow", Math.round(k)); }
      function at(e) { var r = box.getBoundingClientRect(); set((e.clientX - r.left) / r.width * 100); }
      box.addEventListener("pointerdown", function (e) { drag = true; box.setPointerCapture(e.pointerId); at(e); });
      box.addEventListener("pointermove", function (e) { if (drag) at(e); });
      box.addEventListener("pointerup", function () { drag = false; });
      box.addEventListener("keydown", function (e) {
        if (e.key === "ArrowLeft") { set(k - 5); e.preventDefault(); }
        if (e.key === "ArrowRight") { set(k + 5); e.preventDefault(); }
      });
      set(50);
    });
  });

  /* ---- Sound: one track at a time, in the game's look ---- */
  Lux.ready(function () {
    var playing = null;
    Lux.$$("[data-track]").forEach(function (tr) {
      var a = Lux.$("audio", tr), b = Lux.$(".pbtn", tr), bars = Lux.$$(".bars i", tr), prog = Lux.$(".prog b", tr);
      b.addEventListener("click", function () {
        if (!Lux.soundOn) { Lux.toast(["SOUND IS SOLD.", "BUY IT BACK IN SETTINGS."], 2000); return; }
        if (playing && playing !== a) playing.pause();
        if (a.paused) { a.play(); } else a.pause();
      });
      a.addEventListener("play", function () { playing = a; tr.classList.add("on"); b.textContent = "II"; });
      a.addEventListener("pause", function () { tr.classList.remove("on"); b.textContent = "▶"; });
      a.addEventListener("ended", function () { tr.classList.remove("on"); b.textContent = "▶"; });
      a.addEventListener("timeupdate", function () { if (a.duration) prog.style.width = (a.currentTime / a.duration * 100) + "%"; });
      Lux.$(".prog", tr).addEventListener("click", function (e) {
        var r = e.currentTarget.getBoundingClientRect();
        if (a.duration) a.currentTime = (e.clientX - r.left) / r.width * a.duration;
      });
      var acc = 0;
      Lux.onFrame(function (dt) {
        if (a.paused) return;
        acc += dt;
        if (acc < 0.1) return;
        acc = 0;
        bars.forEach(function (i, n) { i.style.height = (20 + Math.abs(Math.sin(a.currentTime * (3 + n) + n)) * 80) + "%"; });
      });
    });
    Lux.stopAudio = function () { if (playing) playing.pause(); };
  });

  /* ---- The run arc: 17 phrases as a strip, coloured by part ---- */
  Lux.ready(function () {
    var box = Lux.$("[data-arc]"), A = Lux.data.arc;
    if (!box || !A || !A.phrases) return;
    var colour = function (id, part) {
      if (part === "night") return P.deep;
      if (part === "light") return P.gold;
      if (/lantern|organ|engine/.test(id)) return P.teal;
      return P.wine;
    };
    var bar = A.bar || 1.6667, html = '<div class="arc-strip">', t = 0;
    A.phrases.forEach(function (p, i) {
      var secs = p.bars * bar;
      html += '<button type="button" class="ph" style="flex-grow:' + p.bars + ';background:' + colour(p.id, p.part) + '" data-i="' + i + '" aria-label="' +
        p.id + ', ' + p.bars + ' bars"></button>';
      p.t = t; t += secs;
    });
    html += '</div><div class="arc-legend px"><span>0:00</span><span class="teal" style="color:var(--jade)">LANTERN OPENING</span><span style="color:var(--rose)">THE THEME</span><span style="color:var(--sky)">NIGHT FALLS</span><span class="gold">LAST LIGHT</span><span>' + Lux.fmt(t) + '</span></div><div class="arc-info">' +
      A.phrases.length + " phrases at " + A.bpm + " BPM, one bar every " + bar.toFixed(2) + " s. Hover or tap a phrase.</div>";
    box.innerHTML = html;
    var info = Lux.$(".arc-info", box);
    Lux.$$(".ph", box).forEach(function (b) {
      function show() {
        Lux.$$(".ph", box).forEach(function (x) { x.classList.remove("on"); });
        b.classList.add("on");
        var p = A.phrases[+b.dataset.i];
        info.textContent = Lux.say("PHRASE " + (+b.dataset.i + 1) + ": " + p.id.toUpperCase() + ". " + p.bars + " BARS FROM " + Lux.fmt(p.t) +
          (p.hold ? ". A HOLD POINT: IT REPEATS UNTIL THE RUN CATCHES UP." : "."));
      }
      b.addEventListener("mouseenter", show); b.addEventListener("focus", show); b.addEventListener("click", show);
    });
  });

  /* ---- The journey: lamps light as you walk the night path ---- */
  Lux.ready(function () {
    var stops = Lux.$$(".stop");
    if (!stops.length) return;
    if (Lux.reduced || !("IntersectionObserver" in window)) { stops.forEach(function (s) { s.classList.add("lit"); }); return; }
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) {
        if (e.isIntersecting && !e.target.classList.contains("lit")) {
          e.target.classList.add("lit");
          if (e.target.querySelector(".q")) Lux.note(Lux.CHORD[stops.indexOf(e.target) % 5], 0.7, 0.04);
        }
      });
    }, { rootMargin: "0px 0px -35% 0px" });
    stops.forEach(function (s) { io.observe(s); });
  });

  /* ---- Counters: numbers roll up when they come into view ---- */
  Lux.ready(function () {
    var cells = Lux.$$("[data-count]");
    if (!cells.length || Lux.reduced || !("IntersectionObserver" in window)) return;
    cells.forEach(function (c) {
      var full = c.getAttribute("data-count"), m = full.match(/^([\d,]+)(.*)$/);
      if (!m) return;
      var target = parseInt(m[1].replace(/,/g, ""), 10), rest = m[2], comma = m[1].indexOf(",") >= 0;
      var fmt = function (n) { var s = String(n); return comma ? s.replace(/\B(?=(\d{3})+(?!\d))/g, ",") : s; };
      c.textContent = fmt(0) + rest;
      var io = new IntersectionObserver(function (es) {
        if (!es[0].isIntersecting) return;
        io.disconnect();
        var t = 0;
        var tick = function (dt) {
          if (t >= 1) return;
          t = Math.min(1, t + dt / 1.2);
          c.textContent = fmt(Math.round(target * (1 - Math.pow(1 - t, 3)))) + rest;
        };
        Lux.onFrame(tick);
      }, { threshold: 0.6 });
      io.observe(c);
    });
  });
})();
