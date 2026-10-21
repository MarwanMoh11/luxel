/* SETTINGS: sell this website's own settings for powers, and the page really gets worse (the game's trade, on the
   page you are reading). Every sale grows the lantern at your cursor. BUY BACK undoes a sale; RESET buys it all
   back. Remembered in localStorage when the browser allows it. */
(function () {
  "use strict";
  var Lux = window.Lux, root = document.documentElement;
  var ROWS = [
    { id: "subtitles", tab: "GENERAL", name: "SUBTITLES", start: "ON", steps: [
      { value: "OFF", power: "+10% LANTERN", quip: "THERE WERE NO SUBTITLES. FREE POWER." }] },
    { id: "font", tab: "GENERAL", name: "FONT", start: "READABLE", steps: [
      { value: "3X5", power: "+20% LANTERN", quip: "EVERY WORD IN THE GAME'S OWN FONT. GOOD LUCK." }] },
    { id: "language", tab: "GENERAL", name: "LANGUAGE", start: "ENGLISH", steps: [
      { value: "GIBBERISH", power: "+1 SHOT", quip: "ALL TEXT TURNS TO NONSENSE. FOR 2 MENUS." }] },
    { id: "hud", tab: "INTERFACE", name: "HUD", start: "SHOWN", steps: [
      { value: "HIDDEN", power: "+2 HEARTS", quip: "MORE HEARTS. YOU JUST CANNOT SEE THEM." }] },
    { id: "colour", tab: "GRAPHICS", name: "COLOURS", start: "20", steps: [
      { value: "4", power: "+20% LANTERN", quip: "FOUR COLOURS. LIKE AN OLD HANDHELD." },
      { value: "2", power: "+25% LANTERN", quip: "BLACK AND WHITE. MOSTLY BLACK." }] },
    { id: "resolution", tab: "GRAPHICS", name: "RESOLUTION", start: "FULL", steps: [
      { value: "HALF", power: "+1 SHOT", quip: "EVERYTHING GETS CHUNKY." },
      { value: "QUARTER", power: "+1 SHOT", quip: "WHICH BLOB IS WICK." }] },
    { id: "animations", tab: "GRAPHICS", name: "ANIMATIONS", start: "ON", steps: [
      { value: "OFF", power: "+15% FIRE RATE", quip: "EVERYONE FREEZES IN ONE POSE." }] },
    { id: "frame_rate", tab: "GRAPHICS", name: "FRAME RATE", start: "60", steps: [
      { value: "20", power: "+15% SPEED", quip: "A SLIDESHOW. WITH TEETH." }] },
    { id: "brightness", tab: "GRAPHICS", name: "BRIGHTNESS", start: "100%", steps: [
      { value: "50%", power: "+1 PIERCE", quip: "ALL THE LANTERNS GO OUT. BUT ONE." }] },
    { id: "sound", tab: "AUDIO", name: "SOUND", start: "ON", steps: [
      { value: "OFF", power: "+30% DAMAGE", quip: "SILENCE. WAS THAT A CLICK." }] },
    { id: "pixels", tab: "ADVANCED", name: "PIXELS", start: "100%", steps: [], special: true }
  ];
  var TABS = ["GENERAL", "INTERFACE", "GRAPHICS", "AUDIO", "ADVANCED"];
  var sold = Lux.store.get("sold", {}) || {};
  var langMenus = Lux.store.get("langMenus", 0) || 0;
  var tab = 0, row = 0, el = null, opener = null, lastQuip = "";

  function lv(id) { return sold[id] || 0; }
  function total() { var n = 0; for (var k in sold) n += sold[k] || 0; return n; }

  /* ---- What the sales do ---- */
  var originals = new WeakMap();
  function scramble(on) {
    Lux.gibberish = on;
    Lux.$$("#page .px, #page .btn, #page .lux .l, #page .tab > a > span:first-child, #page .rows a span, #gear, #page .kicker span").forEach(function (n) {
      if (n.children.length && !n.classList.contains("l")) {
        Lux.$$(":scope > *", n).length;
        n.childNodes.forEach(function (c) { if (c.nodeType === 3) swap(c, on); });
        return;
      }
      n.childNodes.forEach(function (c) { if (c.nodeType === 3) swap(c, on); });
    });
    function swap(node, on2) {
      if (!originals.has(node)) originals.set(node, node.nodeValue);
      var o = originals.get(node);
      node.nodeValue = on2 ? Lux.say(o) : o;
    }
    if (Lux.shopRender) Lux.shopRender();
  }
  function apply() {
    var c = lv("colour"), r = lv("resolution");
    root.classList.toggle("no-subs", lv("subtitles") > 0);
    root.classList.toggle("font-35", lv("font") > 0);
    root.classList.toggle("no-hud", lv("hud") > 0);
    root.classList.toggle("c4", c === 1); root.classList.toggle("c2", c >= 2);
    root.classList.toggle("r2", r === 1); root.classList.toggle("r4", r >= 2);
    root.classList.toggle("dim", lv("brightness") > 0);
    var frozen = lv("animations") > 0;
    if (frozen !== Lux.frozen) { Lux.frozen = frozen; if (Lux.loops) Lux.loops(!frozen); }
    root.classList.toggle("no-anim", frozen);
    Lux.fps = lv("frame_rate") > 0 ? 20 : 60;
    Lux.soundOn = lv("sound") === 0;
    var gib = lv("language") > 0 && langMenus < 2;
    if (gib !== Lux.gibberish) scramble(gib);
    Lux.lanternScale = 1 + Math.min(1.5, total() * 0.15);
    Lux.store.set("sold", sold);
  }
  Lux.buyAllBack = function () { sold = {}; langMenus = 0; Lux.store.set("langMenus", 0); apply(); if (el && el.classList.contains("open")) render(); };
  Lux.sellApply = apply;

  /* ---- The panel ---- */
  function rowsOf(t) { return ROWS.filter(function (r) { return r.tab === TABS[t]; }); }
  function slider(steps, l, dim) {
    steps = Math.max(1, steps);
    var h = '<div class="slider" aria-hidden="true"><div class="rail"></div>';
    for (var k = 0; k <= steps; k++) h += '<div class="notch" style="left:' + (100 * k / steps) + '%"></div>';
    var knob = 100 * (steps - l) / steps;
    h += '<div class="done" style="width:' + knob + '%"></div><div class="knob" style="left:' + knob + '%;background:' +
      (dim ? "var(--mauve)" : l >= steps ? "var(--lime)" : "var(--coral)") + '"></div></div>';
    return h;
  }
  function render() {
    var S = Lux.say, n = total();
    var meter = "";
    for (var i = 0; i < 12; i++) meter += '<i class="' + (i < n ? "on" : "") + '"></i>';
    var h = '<button class="btn small close" type="button" data-close>' + S("BACK") + '</button>' +
      '<div class="m-head"><span class="px px2 gold outlined">' + S("SETTINGS") + '</span></div>' +
      '<div class="m-head"><span class="px stone">' + S(n ? "SOLD " + n + ". THE LANTERN GROWS." : "SELL THIS WEBSITE. ONE SETTING AT A TIME.") + '</span>' +
      '<span class="lantern-meter" title="Lantern">' + meter + '</span></div><div class="m-tabs" role="tablist">';
    TABS.forEach(function (t, i) {
      var stock = rowsOf(i).filter(function (r) { return !r.special && lv(r.id) < r.steps.length; }).length;
      h += '<button type="button" role="tab" class="m-tab' + (i === tab ? " on" : "") + '" data-tab="' + i + '" aria-selected="' + (i === tab) + '"><span>' + S(t) + '</span>' +
        (stock ? '<span class="badge">' + stock + '</span>' : "") + '</button>';
    });
    h += '</div><div class="m-rows" role="listbox" aria-label="' + S("Settings") + '">';
    rowsOf(tab).forEach(function (r, i) {
      var l = lv(r.id), steps = r.steps.length;
      var val = r.special ? "100%" : l === 0 ? r.start : r.steps[l - 1].value;
      var next = r.steps[l], act, pow;
      if (r.special) { pow = S("THE LAST SETTING"); act = '<button type="button" class="btn small" data-pixels>' + S("SELL BELOW") + '</button>'; }
      else if (next) { pow = S(next.power); act = '<button type="button" class="btn small primary" data-sell="' + r.id + '">' + S("SELL") + '</button>'; }
      else { pow = S("SOLD OUT"); act = ""; }
      if (l > 0) act += ' <button type="button" class="btn small ghost" data-back="' + r.id + '">' + S("BUY BACK") + '</button>';
      h += '<div class="m-row px' + (i === row ? " on" : "") + (l ? " sold" : "") + (!next && !r.special ? " out" : "") + '" data-row="' + i + '" role="option" aria-selected="' + (i === row) + '">' +
        '<span class="cursor-tri" aria-hidden="true"></span><span class="nm">' + S(r.name) + '</span>' + slider(steps || 1, r.special ? 0 : l, r.special) +
        '<span class="val">' + S(val) + '</span><span class="pow">' + pow + '</span><span class="act">' + act + '</span></div>';
    });
    var cur = rowsOf(tab)[row], quip;
    if (lastQuip) quip = lastQuip;
    else if (cur.special) quip = "THE SCREEN ITSELF. IT SELLS AT THE BOTTOM OF THE PAGE, 1% AT A TIME.";
    else if (cur.steps[lv(cur.id)]) quip = cur.steps[lv(cur.id)].quip;
    else quip = "SOLD OUT. BUY IT BACK IF YOU MISS IT.";
    h += '</div><div class="m-foot px"><div class="quip">' + S(quip) + '</div>' +
      '<div class="keys-line">' + S("ARROWS: PICK   SPACE: SELL   B: BUY BACK   ESC: BACK") + '</div>' +
      '<p style="margin-top:12px"><button type="button" class="btn small ghost" data-reset>' + S("BUY EVERYTHING BACK") + '</button></p></div>';
    el.querySelector(".panel").innerHTML = h;
  }
  function sell(id) {
    var r = ROWS.filter(function (x) { return x.id === id; })[0];
    if (!r || r.special || lv(id) >= r.steps.length) return;
    sold[id] = lv(id) + 1;
    var st = r.steps[sold[id] - 1];
    lastQuip = "SOLD. " + st.quip;
    if (id === "language") { langMenus = 0; Lux.store.set("langMenus", 0); }
    Lux.note(Lux.CHORD[total() % 5], 0.9, 0.14);
    apply();
    render();
    Lux.toast([st.power, "-" + r.name], 1600);
  }
  function buyBack(id) {
    if (!lv(id)) return;
    sold[id] = lv(id) - 1;
    if (!sold[id]) delete sold[id];
    lastQuip = "BOUGHT BACK. YOU KEEP THE POWER. THIS ONCE.";
    Lux.note(69, 0.6, 0.1);
    apply();
    render();
  }
  function open() {
    if (lv("language") > 0 && langMenus < 2) {
      langMenus++;
      Lux.store.set("langMenus", langMenus);
      if (langMenus >= 2) { apply(); Lux.toast(["ENGLISH!", "LANGUAGE WORE OFF. +1 SHOT STAYS."], 2400); }
    }
    opener = document.activeElement;
    lastQuip = "";
    render();
    el.classList.add("open");
    var b = el.querySelector(".m-row.on .btn") || el.querySelector("[data-close]");
    if (b) b.focus();
    Lux.note(81, 0.4, 0.08);
  }
  function close() {
    el.classList.remove("open");
    if (opener && opener.focus) opener.focus();
  }
  Lux.openSell = open;

  Lux.ready(function () {
    el = document.getElementById("sell");
    var gear = document.getElementById("gear");
    if (!el || !gear) return;
    el.innerHTML = '<div class="veil" data-close></div><div class="panel shop" tabindex="-1"></div>';
    gear.addEventListener("click", open);
    el.addEventListener("click", function (e) {
      var t = e.target.closest("button, .m-row, .veil");
      if (!t) return;
      if (t.hasAttribute("data-close")) { close(); return; }
      if (t.hasAttribute("data-tab")) { tab = +t.getAttribute("data-tab"); row = 0; lastQuip = ""; render(); el.querySelector('[data-tab="' + tab + '"]').focus(); return; }
      if (t.hasAttribute("data-sell")) { sell(t.getAttribute("data-sell")); refocus(); return; }
      if (t.hasAttribute("data-back")) { buyBack(t.getAttribute("data-back")); refocus(); return; }
      if (t.hasAttribute("data-reset")) { Lux.buyAllBack(); lastQuip = "EVERYTHING BOUGHT BACK. THE LANTERN SHRINKS."; render(); return; }
      if (t.hasAttribute("data-pixels")) { close(); var f = document.getElementById("display-off"); if (f) f.scrollIntoView({ behavior: Lux.reduced ? "auto" : "smooth" }); return; }
      if (t.classList.contains("m-row")) { row = +t.getAttribute("data-row"); lastQuip = ""; render(); }
    });
    function refocus() { var b = el.querySelector(".m-row.on .btn") || el.querySelector("[data-close]"); if (b) b.focus(); }
    el.addEventListener("keydown", function (e) {
      var n = rowsOf(tab).length, k = e.key, id = rowsOf(tab)[row].id;
      if (k === "Escape") { close(); e.preventDefault(); return; }
      if (k === "ArrowDown") row = (row + 1) % n;
      else if (k === "ArrowUp") row = (row + n - 1) % n;
      else if (k === "ArrowRight") { tab = (tab + 1) % TABS.length; row = 0; }
      else if (k === "ArrowLeft") { tab = (tab + TABS.length - 1) % TABS.length; row = 0; }
      else if (k === "b" || k === "B") { buyBack(id); refocus(); e.preventDefault(); return; }
      else if ((k === " " || k === "Enter") && !e.target.closest("button")) { sell(id); refocus(); e.preventDefault(); return; }
      else if (k === "Tab") {
        var f = Lux.$$("button", el), i = f.indexOf(document.activeElement);
        if (e.shiftKey && i <= 0) { f[f.length - 1].focus(); e.preventDefault(); }
        else if (!e.shiftKey && i === f.length - 1) { f[0].focus(); e.preventDefault(); }
        return;
      } else return;
      e.preventDefault();
      lastQuip = "";
      render();
      refocus();
    });
    apply();
    if (total()) Lux.toast(["THE PAGE REMEMBERS WHAT YOU SOLD.", "SETTINGS: BUY IT BACK."], 3000);
  });
})();
