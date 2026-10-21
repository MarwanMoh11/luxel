/* DISPLAY: OFF. Each press sells 1% of the screen: the dark eats it in luxels, from the edges in, with the next
   lantern note. After 5 presses AUTO-SELL sells the rest. Then black, a gold pixel, and the lantern bursts the page
   back, ending on A GAME BY MARWAN. ESC or BUY IT ALL BACK stops it at any point. */
(function () {
  "use strict";
  var Lux = window.Lux, P = Lux.PAL;
  Lux.ready(function () {
    var panel = Lux.$("[data-pixels]"), cv = document.getElementById("eat"), ui = document.getElementById("eat-ui"), end = document.getElementById("ending");
    if (!panel || !cv || !ui || !end) return;
    var x = cv.getContext("2d"), K = 3, CELL = 5, cols = 0, rows = 0, order = [], eaten = 0, pct = 0, presses = 0;
    var anim = [], phase = "idle", auto = false, autoAcc = 0, t = 0, burstR = 0, cx = 0, cy = 0, lastFocus = null;
    var sellBtn = Lux.$("[data-sell-pixel]", panel);

    function setup() {
      K = window.innerWidth < 760 ? 2 : 3;
      cv.width = Math.ceil(window.innerWidth / K); cv.height = Math.ceil(window.innerHeight / K);
      cols = Math.ceil(cv.width / CELL); rows = Math.ceil(cv.height / CELL);
      cx = Math.floor(cols / 2); cy = Math.floor(rows / 2);
      /* the dark comes from the edges, in blobs: noise plus the distance to the centre */
      var r = Lux.rng(29), cells = [];
      for (var j = 0; j < rows; j++) for (var i = 0; i < cols; i++) {
        var dx = (i - cx) / (cols / 2), dy = (j - cy) / (rows / 2), d = Math.sqrt(dx * dx + dy * dy) / 1.414;
        var n = Lux.hash(Math.floor(i / 4), Math.floor(j / 4)) * 0.5 + Lux.hash(Math.floor(i / 2) + 99, Math.floor(j / 2)) * 0.25 + r() * 0.25;
        cells.push({ i: i, j: j, v: (1 - d) * 1.1 + n * 0.75 });
      }
      cells.sort(function (a, b) { return a.v - b.v; });
      order = cells.filter(function (c) { return !(c.i === cx && c.j === cy); });
      order.push({ i: cx, j: cy });
      x.clearRect(0, 0, cv.width, cv.height);
    }
    function cellsFor(p) { return Math.round(order.length * p / 100); }

    function renderUI() {
      var S = Lux.say, left = 100 - pct;
      var h = '<div class="pixels-row px on"><span class="cursor-tri" aria-hidden="true"></span><span>' + S("PIXELS") + '</span>' +
        '<span class="fill-bar"><b style="width:' + left + '%"></b></span><span class="val">' + (left <= 0 ? "OFF" : left + "%") + '</span></div>' +
        '<p class="px ' + (presses ? "gold" : "stone") + '" style="margin:6px 0">' + S(auto ? "KEEP WATCHING. THE SCREEN SELLS ITSELF." : presses ? "-1% PIXELS." : "THE LANTERN WANTS THE GOOD STUFF") + '</p>' +
        '<p class="pix-actions" style="margin-top:8px">' +
        (auto ? "" : '<button class="btn small primary" type="button" data-e="sell">' + S("SPACE: SELL 1%") + '</button>') +
        (presses >= 5 && !auto ? '<button class="btn small" type="button" data-e="auto">' + S("AUTO-SELL") + '</button>' : "") +
        '<button class="btn small ghost" type="button" data-e="back">' + S("ESC: BUY IT ALL BACK") + '</button></p>';
      ui.innerHTML = h;
      var fb = Lux.$(".fill-bar b", panel), pv = Lux.$(".val", panel);
      if (fb) fb.style.width = left + "%";
      if (pv) pv.textContent = left <= 0 ? "OFF" : left + "%";
      var f = Lux.$("[data-e=sell]", ui) || Lux.$("[data-e=back]", ui);
      if (f && document.activeElement && ui.contains(document.activeElement) === false && phase === "eat") f.focus({ preventScroll: true });
    }

    function begin() {
      if (phase !== "idle") return;
      lastFocus = document.activeElement;
      /* the lantern wants the good stuff: the page jumps to its prettiest screen, then sells it */
      try { window.scrollTo({ top: 0, left: 0, behavior: "instant" }); } catch (e) { window.scrollTo(0, 0); }
      document.documentElement.classList.add("locked");
      setup();
      phase = "eat"; pct = 0; eaten = 0; presses = 0; auto = false; anim = [];
      cv.classList.add("on"); ui.classList.add("on");
      document.addEventListener("keydown", keys, true);
      Lux.stopAudio && Lux.stopAudio();
      renderUI();
    }
    function sellOne() {
      if (phase !== "eat") return;
      presses++;
      pct = Math.min(100, pct + 1);
      var to = cellsFor(pct);
      for (; eaten < to; eaten++) anim.push({ c: order[eaten], t: 0 });
      Lux.note(Lux.CHORD[(pct - 1) % 5] - 12 * Math.floor(((pct - 1) % 15) / 5), 0.7, 0.13);
      if (pct >= 100) off();
      else if (!auto) renderUI();
    }
    function keys(e) {
      if (phase === "eat" && (e.key === " " || e.key === "Spacebar")) { e.preventDefault(); if (!auto) sellOne(); }
      else if (e.key === "Escape") { e.preventDefault(); abort(); }
    }
    ui.addEventListener("click", function (e) {
      var b = e.target.closest("[data-e]");
      if (!b) return;
      var a = b.getAttribute("data-e");
      if (a === "sell") sellOne();
      if (a === "auto") { auto = true; autoAcc = 0; renderUI(); Lux.toast(["AUTO-SELL ON."], 1400); }
      if (a === "back") abort();
    });
    sellBtn.addEventListener("click", function () { begin(); sellOne(); });

    function off() {
      phase = "off"; t = 0; auto = false;
      ui.classList.remove("on");
      anim = [];
      x.fillStyle = P.void; x.fillRect(0, 0, cv.width, cv.height);
      Lux.snuff();
    }
    function abort() {
      phase = "idle";
      document.documentElement.classList.remove("locked");
      pct = 0; renderUI();
      cv.classList.remove("on"); ui.classList.remove("on");
      x.clearRect(0, 0, cv.width, cv.height);
      document.removeEventListener("keydown", keys, true);
      Lux.toast(["BOUGHT BACK.", "THE SCREEN IS YOURS AGAIN."], 1800);
      if (lastFocus && lastFocus.focus) lastFocus.focus({ preventScroll: true });
    }

    function drawCell(c, state) {
      var px = c.i * CELL, py = c.j * CELL;
      x.clearRect(px, py, CELL, CELL);
      if (state === "void") { x.fillStyle = P.void; x.fillRect(px, py, CELL, CELL); return; }
      x.fillStyle = P.void; x.fillRect(px, py, CELL, CELL);
      Lux.drawLuxel(x, px, py, state, 4);
    }

    Lux.onFrame(function (dt) {
      if (phase === "idle" || phase === "done") return;
      dt = dt || 1 / 60;
      if (phase === "eat") {
        if (auto) {
          autoAcc += dt;
          var gap = Math.max(0.035, 0.22 - pct * 0.002);
          while (autoAcc >= gap && phase === "eat") { autoAcc -= gap; presses++; pct++; var to = cellsFor(pct); for (; eaten < to; eaten++) anim.push({ c: order[eaten], t: 0 });
            Lux.note(Lux.CHORD[(pct - 1) % 5] - 12 * Math.floor(((pct - 1) % 15) / 5), 0.5, 0.08);
            if (pct >= 100) { off(); return; } }
          renderUI();
        }
        for (var k = anim.length - 1; k >= 0; k--) {
          var a = anim[k];
          a.t += dt;
          var st = Lux.reduced ? "void" : a.t < 0.06 ? "ember" : a.t < 0.18 ? "unlit" : "void";
          drawCell(a.c, st);
          if (st === "void") anim.splice(k, 1);
        }
      } else if (phase === "off") {
        t += dt;
        x.fillStyle = P.void; x.fillRect(0, 0, cv.width, cv.height);
        if (t > 0.3 && t < 1.6) Lux.drawCentered(x, Lux.say("DISPLAY: OFF"), cv.width / 2, cv.height / 2 - 18, P.mauve, null, 1);
        if (t > 1.9) {
          var on = Lux.reduced || Math.floor(t * 6) % 3 !== 0 || t > 3.2;
          Lux.drawLuxel(x, cx * CELL, cy * CELL, on ? (t > 3.2 ? "flash" : "lit") : "dim", 4);
          if (t > 1.9 && t - dt <= 1.9) Lux.note(74, 1.6, 0.12);
        }
        if (t > 3.4) { phase = "burst"; burstR = 0; Lux.CHORD.forEach(function (m, i) { setTimeout(function () { Lux.note(m, 1.8, 0.1); }, i * 70); }); Lux.buyAllBack(); if (Lux.heroRelight) Lux.heroRelight(); }
      } else if (phase === "burst") {
        var far = Math.sqrt(cols * cols + rows * rows) / 2 + 4;
        burstR += dt * far / (Lux.reduced ? 0.05 : 0.9);
        x.fillStyle = P.void;
        for (var j = 0; j < rows; j++) for (var i = 0; i < cols; i++) {
          var d = Math.sqrt((i - cx) * (i - cx) + (j - cy) * (j - cy));
          var px = i * CELL, py = j * CELL;
          if (d < burstR - 3) x.clearRect(px, py, CELL, CELL);
          else if (d < burstR) { x.clearRect(px, py, CELL, CELL); Lux.drawLuxel(x, px, py, d < burstR - 1.5 ? "lit" : "flash", 4); }
        }
        if (burstR > far + 4) { finish(); }
      }
    });

    function finish() {
      phase = "done";
      document.documentElement.classList.remove("locked");
      pct = 0; renderUI(); ui.classList.remove("on");
      cv.classList.remove("on");
      x.clearRect(0, 0, cv.width, cv.height);
      document.removeEventListener("keydown", keys, true);
      var L = Lux.data.links || {};
      end.innerHTML = '<div class="panel"><p class="px stone">THE LANTERN KEPT EVERYTHING YOU SOLD.</p>' +
        '<p class="px gold" style="margin-top:6px">IT WAS TOO MUCH LIGHT FOR THE DARK.</p>' +
        '<h2 class="sr-only" id="ending-title">LUXEL</h2><canvas class="pix" data-end aria-hidden="true"></canvas>' +
        '<p class="px px2 cream outlined" style="margin:0 0 20px">A GAME BY MARWAN</p>' +
        '<p class="pix-actions" style="justify-content:center"><a class="btn primary" href="#play">▶ PLAY</a>' +
        '<a class="btn" href="' + (L.releases || "#") + '" rel="noopener">DOWNLOAD</a>' +
        '<a class="btn ghost" href="' + (L.repo || "#") + '" rel="noopener">SOURCE</a></p>' +
        '<p style="margin-top:18px"><button class="btn small ghost" type="button" data-x>BACK TO THE PAGE</button></p>' +
        '<p class="stone" style="margin:14px 0 0;font-size:.85em">© 2026 Marwan. All rights reserved.</p></div>';
      end.classList.add("on");
      titleBuild(Lux.$("canvas[data-end]", end));
      var close = function () { end.classList.remove("on"); phase = "idle"; if (lastFocus && lastFocus.focus) lastFocus.focus({ preventScroll: true }); };
      Lux.$("[data-x]", end).addEventListener("click", close);
      Lux.$$("a", end).forEach(function (a) { a.addEventListener("click", function () { end.classList.remove("on"); phase = "idle"; }); });
      end.addEventListener("keydown", function (e) { if (e.key === "Escape") close(); });
      Lux.$("[data-x]", end).focus({ preventScroll: true });
    }
    /* LUXEL builds itself out of luxels, west to east, one lantern note each (the ending's bar 15) */
    function titleBuild(c) {
      var cells = Lux.luxelCells("LUXEL", 1, 1, 5), k = window.innerWidth < 760 ? 2 : 3, tt = 0;
      c.width = 19 * 5 + 1; c.height = 26;
      c.style.width = c.width * k + "px"; c.style.height = c.height * k + "px";
      var g = c.getContext("2d");
      var tick = function (dt) {
        if (!end.classList.contains("on")) return;
        var before = tt;
        tt += dt || 0.016;
        g.clearRect(0, 0, c.width, c.height);
        cells.forEach(function (cell, i) {
          var at = Lux.reduced ? 0 : 0.2 + i * 0.03;
          if (tt < at) return;
          if (before < at && !Lux.reduced && i % 3 === 0) Lux.note(Lux.CHORD[cell.row], 0.6, 0.05);
          var st = tt < at + 0.08 ? "flash" : Lux.hash(i, Math.floor(tt / 0.14)) < 0.05 ? "dim" : "lit";
          Lux.drawLuxel(g, cell.x, cell.y, st, 4);
        });
      };
      tick(0);
      Lux.onFrame(tick);
    }
    window.addEventListener("resize", function () { if (phase === "eat") { var p = pct; setup(); pct = p; eaten = cellsFor(p); for (var i = 0; i < eaten; i++) drawCell(order[i], "void"); } });
  });
})();
