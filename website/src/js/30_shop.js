/* The shop section: the game's level-up menu (scripts/game/ui/settings_menu.gd) built from shop_data.gd, to
   browse with the arrows or the mouse. Selling here only moves the sliders; reset puts everything back. */
(function () {
  "use strict";
  var Lux = window.Lux;
  Lux.ready(function () {
    var box = Lux.$("[data-shop]"), D = Lux.data.shop;
    if (!box || !D) return;
    var tab = 0, row = 0, sold = {}, level = 2, stamp = -1;
    box.innerHTML =
      '<div class="m-head"><span class="px px2 gold outlined" data-h>LEVEL UP!</span><span class="px stone" data-lv>LV 2</span></div>' +
      '<div class="m-head"><span></span><span class="px stone" data-sub>SELL ONE SETTING</span></div>' +
      '<div class="m-tabs" role="tablist"></div><div class="m-rows" role="listbox" aria-label="Settings"></div>' +
      '<div class="m-foot px"><div class="quip" data-quip></div><div class="lime" data-pow></div>' +
      '<div class="keys-line" data-keys>ARROWS: PICK   SPACE: SELL   R: RESET</div></div>';
    var tabsEl = Lux.$(".m-tabs", box), rowsEl = Lux.$(".m-rows", box);
    function rowsOf(t) { return D.tabs[t].rows; }
    function lv(id) { return sold[id] || 0; }
    function stock(t) { return rowsOf(t).filter(function (id) { var r = D.rows[id]; return !r.beauty && r.act < 4 && lv(id) < r.steps.length; }).length; }
    function sellable(id) { var r = D.rows[id]; return !r.beauty && r.act < 4 && lv(id) < r.steps.length; }
    function totalSold() { var n = 0; for (var k in sold) n += sold[k]; return n; }
    function slider(steps, l, dim) {
      steps = Math.max(1, steps);
      var h = '<div class="slider" aria-hidden="true"><div class="rail"' + (dim ? ' style="background:var(--mauve)"' : "") + '></div>';
      for (var k = 0; k <= steps; k++) h += '<div class="notch" style="left:' + (100 * k / steps) + '%' + (dim ? ';background:var(--mauve)' : "") + '"></div>';
      var knob = 100 * (steps - l) / steps;
      h += '<div class="done" style="width:' + knob + '%' + (dim ? ';background:var(--mauve)' : "") + '"></div>';
      h += '<div class="knob" style="left:' + knob + '%;background:' + (dim ? "var(--mauve)" : l >= steps ? "var(--lime)" : "var(--coral)") + '"></div></div>';
      return h;
    }
    function render() {
      tabsEl.innerHTML = "";
      D.tabs.forEach(function (t, i) {
        var b = document.createElement("button");
        b.type = "button"; b.className = "m-tab" + (i === tab ? " on" : "");
        b.setAttribute("role", "tab"); b.setAttribute("aria-selected", String(i === tab));
        var n = stock(i), locked = !n && rowsOf(i).some(function (id) { return D.rows[id].beauty || D.rows[id].act >= 4; });
        b.innerHTML = '<span>' + Lux.say(t.name) + '</span>' + (n ? '<span class="badge">' + Math.min(9, n) + '</span>' : locked ? '<span aria-label="locked" class="stone">·</span>' : "");
        b.addEventListener("click", function () { tab = i; row = 0; stamp = -1; render(); Lux.note(81, 0.25, 0.05); });
        tabsEl.appendChild(b);
      });
      rowsEl.innerHTML = "";
      var ids = rowsOf(tab);
      if (row >= ids.length) row = ids.length - 1;
      ids.forEach(function (id, i) {
        var r = D.rows[id], l = lv(id), steps = r.steps.length || 1;
        var val = l === 0 ? r.start : (r.steps[l - 1] || {}).value;
        var later = r.beauty || r.act >= 4, out = !later && l >= r.steps.length;
        var next = r.steps[l] || r.steps[r.steps.length - 1] || { label: "" };
        var pow = later ? "NOT FOR SALE YET" : out ? "SOLD OUT" : next.label;
        if (id === "pixels") pow = "1% AT A TIME";
        var d = document.createElement("div");
        d.className = "m-row" + (i === row ? " on" : "") + (later ? " beauty" : "");
        d.setAttribute("role", "option"); d.setAttribute("aria-selected", String(i === row));
        d.innerHTML = '<span class="cursor-tri" aria-hidden="true"></span><span class="nm">' + Lux.say(r.name) + '</span>' +
          slider(steps, l, later) + '<span class="val">' + Lux.say(val) + '</span><span class="pow">' + Lux.say(pow) + '</span>';
        d.addEventListener("mouseenter", function () { if (row !== i) { row = i; stamp = -1; render(); } });
        d.addEventListener("click", function () { row = i; sell(); });
        rowsEl.appendChild(d);
      });
      var cur = D.rows[ids[row]], l2 = lv(ids[row]);
      var q = Lux.$("[data-quip]", box), pw = Lux.$("[data-pow]", box);
      if (stamp === row) {
        q.innerHTML = '<span class="stamp">SOLD</span> ' + Lux.say((cur.steps[l2 - 1] || {}).quip || "");
        pw.textContent = Lux.say((cur.steps[l2 - 1] || {}).label || "");
      } else if (cur.beauty) {
        q.textContent = Lux.say("NOT FOR SALE YET. THE PRETTY SETTINGS GO AT THE END.");
        pw.textContent = "";
      } else if (cur.act >= 4) {
        q.textContent = Lux.say(ids[row] === "pixels" ? "THE LAST THING YOU OWN. SEE THE BOTTOM OF THIS PAGE." : "LATER. THE ADVANCED TAB OPENS AT THE END OF THE NIGHT.");
        pw.textContent = "";
      } else if (l2 >= cur.steps.length) {
        q.textContent = Lux.say("SOLD OUT. " + (cur.steps[cur.steps.length - 1] || {}).quip);
        pw.textContent = "";
      } else {
        q.textContent = Lux.say(cur.steps[l2].quip);
        pw.textContent = "";
      }
      Lux.$("[data-lv]", box).textContent = "LV " + level;
      Lux.$("[data-sub]", box).textContent = Lux.say(totalSold() ? "SOLD " + totalSold() + " OF 19" : "SELL ONE SETTING");
    }
    function sell() {
      var id = rowsOf(tab)[row];
      if (sellable(id)) {
        sold[id] = lv(id) + 1; level++; stamp = row;
        Lux.note(Lux.CHORD[level % 5], 0.8, 0.12);
      } else { stamp = -1; Lux.note(62, 0.2, 0.05); }
      render();
    }
    box.addEventListener("keydown", function (e) {
      var n = rowsOf(tab).length, k = e.key;
      if (k === "ArrowDown") { row = (row + 1) % n; stamp = -1; }
      else if (k === "ArrowUp") { row = (row + n - 1) % n; stamp = -1; }
      else if (k === "ArrowRight") { tab = (tab + 1) % D.tabs.length; row = 0; stamp = -1; }
      else if (k === "ArrowLeft") { tab = (tab + D.tabs.length - 1) % D.tabs.length; row = 0; stamp = -1; }
      else if (k === " " || k === "Enter") { sell(); e.preventDefault(); return; }
      else if (k === "r" || k === "R") { sold = {}; level = 2; stamp = -1; }
      else return;
      e.preventDefault();
      render();
    });
    render();
    Lux.shopRender = render;
  });
})();
