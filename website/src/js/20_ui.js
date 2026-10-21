/* The page around the content: the night sky, the Settings-menu navigation, the lantern at the cursor, luxel
   headings that light as they scroll in, the trailer player, the game loader, loops and the image viewer. */
(function () {
  "use strict";
  var Lux = window.Lux, P = Lux.PAL;

  /* ---- The night sky: a fixed starfield at low resolution ---- */
  (function sky() {
    var c = document.getElementById("sky");
    if (!c) return;
    var x = c.getContext("2d"), stars = [], S = 3, w = 0, h = 0, acc = 0;
    function size() {
      S = window.innerWidth < 760 ? 2 : 3;
      w = Math.ceil(window.innerWidth / S); h = Math.ceil(window.innerHeight / S);
      c.width = w; c.height = h;
      var r = Lux.rng(11);
      stars = [];
      for (var i = 0; i < w * h / 320; i++) {
        var k = r();
        stars.push({ x: Math.floor(r() * w), y: Math.floor(r() * h), c: k < 0.6 ? "dusk" : k < 0.85 ? "mauve" : k < 0.95 ? "stone" : "ice", p: r() * 10, big: r() < 0.04 });
      }
      draw(0);
    }
    function draw(t) {
      x.fillStyle = P.void; x.fillRect(0, 0, w, h);
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i], on = Math.sin(t * 0.9 + s.p * 7) > -0.7;
        if (!on) continue;
        x.fillStyle = P[s.c];
        x.fillRect(s.x, s.y, 1, 1);
        if (s.big && Math.sin(t * 1.7 + s.p) > 0.3) { x.fillRect(s.x - 1, s.y, 3, 1); x.fillRect(s.x, s.y - 1, 1, 3); }
      }
    }
    size();
    window.addEventListener("resize", size);
    if (!Lux.reduced) Lux.onFrame(function (dt, now) { acc += dt; if (acc > 0.25) { acc = 0; draw(now); } });
  })();

  /* ---- Navigation: tabs stand up for the section in view; MENU on small screens ---- */
  Lux.ready(function () {
    var tabs = Lux.$$(".tab"), rows = Lux.$$(".rows a"), secs = Lux.$$("main .section");
    var mb = Lux.$(".menu-btn"), mm = document.getElementById("mobile-menu");
    if (mb && mm) {
      mb.addEventListener("click", function () {
        var open = !mm.hasAttribute("open");
        if (open) mm.setAttribute("open", ""); else mm.removeAttribute("open");
        mb.setAttribute("aria-expanded", String(open));
        mb.textContent = Lux.say(open ? "CLOSE" : "MENU");
        Lux.note(open ? 81 : 74, 0.4, 0.08);
      });
      mm.addEventListener("click", function (e) {
        if (e.target.closest("a")) { mm.removeAttribute("open"); mb.setAttribute("aria-expanded", "false"); mb.textContent = Lux.say("MENU"); }
      });
    }
    if (!("IntersectionObserver" in window)) return;
    var current = null;
    var io = new IntersectionObserver(function (es) {
      es.forEach(function (e) { e.target._vis = e.isIntersecting ? e.intersectionRatio : 0; });
      var best = null;
      secs.forEach(function (s) { if (s._vis && (!best || s._vis > best._vis)) best = s; });
      if (!best || best === current) return;
      current = best;
      var tab = best.getAttribute("data-tab"), id = best.id;
      tabs.forEach(function (t) { t.classList.toggle("on", t.getAttribute("data-tab") === tab); });
      rows.forEach(function (a) { a.classList.toggle("here", a.getAttribute("href") === "#" + id); });
    }, { threshold: [0, 0.15, 0.4, 0.7], rootMargin: "-64px 0px -30% 0px" });
    secs.forEach(function (s) { io.observe(s); });
  });

  /* ---- The lantern that follows the cursor (mouse only) ---- */
  Lux.ready(function () {
    var g = document.getElementById("glow");
    if (!g || !window.matchMedia || !window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;
    document.documentElement.classList.add("has-mouse");
    var tx = -999, ty = -999, x = -999, y = -999, shown = false;
    window.addEventListener("pointermove", function (e) {
      if (e.pointerType !== "mouse") return;
      tx = e.clientX; ty = e.clientY;
      if (!shown) { x = tx; y = ty; shown = true; g.style.opacity = "1"; }
    }, { passive: true });
    document.addEventListener("mouseleave", function () { shown = false; g.style.opacity = "0"; });
    Lux.lanternScale = 1;
    Lux.onFrame(function (dt) {
      if (!shown) return;
      var o = Lux.overHero ? "0" : "1";
      if (g.style.opacity !== o) g.style.opacity = o;
      var k = Lux.reduced || Lux.frozen ? 1 : Math.min(1, dt * 10);
      if (Lux.frozen) return;
      x += (tx - x) * k; y += (ty - y) * k;
      var sx = Math.round(x / 3) * 3, sy = Math.round(y / 3) * 3;
      g.style.transform = "translate(" + sx + "px," + sy + "px) scale(" + Lux.lanternScale + ")";
    });
  });

  /* ---- Luxel headings: each letter a span; they light west to east as the heading scrolls in ---- */
  Lux.ready(function () {
    Lux.$$("[data-lux]").forEach(function (h) {
      var text = h.textContent;
      h.setAttribute("aria-label", text);
      h.innerHTML = "";
      var holder = document.createElement("span");
      holder.setAttribute("aria-hidden", "true");
      text.split(" ").forEach(function (word, wi, arr) {
        var w = document.createElement("span");
        w.className = "w";
        for (var i = 0; i < word.length; i++) {
          var l = document.createElement("span");
          l.className = "l" + (Lux.reduced ? "" : " u");
          l.textContent = word[i];
          l.setAttribute("data-c", word[i]);
          w.appendChild(l);
        }
        holder.appendChild(w);
        if (wi < arr.length - 1) holder.appendChild(document.createTextNode(" "));
      });
      h.appendChild(holder);
      if (Lux.reduced || !("IntersectionObserver" in window)) { Lux.$$(".l", h).forEach(function (l) { l.className = "l"; }); return; }
      var io = new IntersectionObserver(function (es) {
        es.forEach(function (e) {
          if (!e.isIntersecting) return;
          io.disconnect();
          Lux.$$(".l", h).forEach(function (l, i) {
            setTimeout(function () { l.className = "l f"; }, 60 + i * 55);
            setTimeout(function () { l.className = "l"; }, 60 + i * 55 + 90);
          });
        });
      }, { threshold: 0.6 });
      io.observe(h);
    });
  });

  /* ---- The trailer player, in the game's look ---- */
  Lux.ready(function () {
    Lux.$$("[data-player]").forEach(function (box) {
      var v = Lux.$("video", box), big = Lux.$(".big-play", box), playB = Lux.$('[data-act="play"]', box);
      var muteB = Lux.$('[data-act="mute"]', box), fullB = Lux.$('[data-act="full"]', box);
      var seek = Lux.$(".seek", box), fill = Lux.$(".fill", box), knob = Lux.$(".knob", box), time = Lux.$(".time", box);
      if (!v) return;
      v.removeAttribute("controls");
      function snap() {
        var avail = box.parentNode.getBoundingClientRect().width;
        var k = Math.floor(avail / 320);
        box.style.width = (k >= 2 ? k * 320 : avail) + "px";
      }
      snap(); window.addEventListener("resize", snap);
      function toggle() {
        if (v.paused) { v.play(); } else { v.pause(); }
      }
      big.addEventListener("click", toggle);
      playB.addEventListener("click", toggle);
      v.addEventListener("click", toggle);
      v.addEventListener("play", function () { box.classList.add("playing"); playB.textContent = Lux.say("PAUSE"); });
      v.addEventListener("pause", function () { playB.textContent = Lux.say("PLAY"); });
      v.addEventListener("ended", function () { box.classList.remove("playing"); });
      muteB.addEventListener("click", function () { v.muted = !v.muted; muteB.textContent = Lux.say(v.muted ? "SOUND: OFF" : "SOUND: ON"); });
      fullB.addEventListener("click", function () {
        var el = box;
        if (document.fullscreenElement) document.exitFullscreen();
        else if (el.requestFullscreen) el.requestFullscreen();
        else if (v.webkitEnterFullscreen) v.webkitEnterFullscreen();
      });
      function upd() {
        var k = v.duration ? v.currentTime / v.duration : 0;
        fill.style.width = k * 100 + "%"; knob.style.left = k * 100 + "%";
        time.textContent = Lux.fmt(v.currentTime) + " / " + Lux.fmt(v.duration);
        seek.setAttribute("aria-valuenow", Math.round(k * 100));
      }
      v.addEventListener("timeupdate", upd);
      v.addEventListener("loadedmetadata", upd);
      function seekTo(e) {
        var r = seek.getBoundingClientRect();
        if (v.duration) v.currentTime = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * v.duration;
      }
      var drag = false;
      seek.addEventListener("pointerdown", function (e) { drag = true; seek.setPointerCapture(e.pointerId); if (v.preload === "none") v.preload = "metadata"; seekTo(e); });
      seek.addEventListener("pointermove", function (e) { if (drag) seekTo(e); });
      seek.addEventListener("pointerup", function () { drag = false; });
      seek.addEventListener("keydown", function (e) {
        if (!v.duration) return;
        if (e.key === "ArrowRight") { v.currentTime = Math.min(v.duration, v.currentTime + 5); e.preventDefault(); }
        if (e.key === "ArrowLeft") { v.currentTime = Math.max(0, v.currentTime - 5); e.preventDefault(); }
      });
    });
  });

  /* ---- Play here: the game loads only on a click ---- */
  Lux.ready(function () {
    Lux.$$("[data-load-game]").forEach(function (b) {
      b.addEventListener("click", function () {
        var box = b.closest("[data-play]");
        var f = document.createElement("iframe");
        f.src = (Lux.data.links && Lux.data.links.play) || "play/";
        f.title = "Luxel, playable";
        f.allow = "autoplay; fullscreen; gamepad";
        box.innerHTML = "";
        box.appendChild(f);
        setTimeout(function () { try { f.focus(); } catch (e) { /* cross-origin */ } }, 300);
      });
    });
  });

  /* ---- Loops play only while on screen; pixel images get integer scales ---- */
  Lux.ready(function () {
    Lux.$$("video[data-autoplay-inview]").forEach(function (v) {
      v.muted = true;
      if (Lux.reduced) { v.controls = true; return; } /* reduced motion: loops wait for a click */
      Lux.watch(v, function (vis) {
        if (vis && !Lux.frozen && !Lux.reduced) { v.preload = "auto"; var p = v.play(); if (p && p.catch) p.catch(function () {}); }
        else v.pause();
      }, "0px");
    });
    Lux.loops = function (run) {
      Lux.$$("video[data-autoplay-inview]").forEach(function (v) { if (run) { if (v.getBoundingClientRect().bottom > 0 && v.getBoundingClientRect().top < innerHeight) v.play().catch(function () {}); } else v.pause(); });
      Lux.$$("[data-player] video").forEach(function (v) { if (!run) v.pause(); });
    };
  });

  /* ---- Image viewer ---- */
  Lux.ready(function () {
    var lb = document.getElementById("lightbox");
    if (!lb) return;
    var img = Lux.$("img", lb), cap = Lux.$(".cap", lb), back = null;
    function close() { lb.classList.remove("open"); img.removeAttribute("src"); if (back) back.focus(); }
    document.addEventListener("click", function (e) {
      var z = e.target.closest(".zoomable");
      if (z && z.tagName === "IMG") {
        back = z;
        img.src = z.currentSrc || z.src; img.alt = z.alt;
        var fc = z.closest("figure");
        cap.textContent = (fc && Lux.$("figcaption", fc) ? Lux.$("figcaption", fc).textContent : z.alt) || "";
        lb.classList.add("open");
        Lux.$("[data-close]", lb).focus();
      }
    });
    lb.addEventListener("click", function (e) { if (e.target === lb || e.target.hasAttribute("data-close")) close(); });
    document.addEventListener("keydown", function (e) { if (e.key === "Escape" && lb.classList.contains("open")) close(); });
    document.addEventListener("keydown", function (e) {
      if (e.key !== "Enter") return;
      var z = document.activeElement;
      if (z && z.classList && z.classList.contains("zoomable")) z.click();
    });
    Lux.$$(".zoomable").forEach(function (z) { z.setAttribute("tabindex", "0"); z.setAttribute("role", "button"); });
  });
})();
