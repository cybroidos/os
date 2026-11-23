// CybroidOS 0.1.16 (cybroid-plasma): accounts made before the account menu
// existed get it at the far right of their top bar. Plasma runs each script
// here once per account (plasmashellrc, [Updates] performed).
var all = panels();
for (var i = 0; i < all.length; i++) {
    var bar = all[i];
    if (bar.location !== "top") continue;
    var has = false, ours = false;
    var ws = bar.widgets();
    for (var j = 0; j < ws.length; j++) {
        if (ws[j].type === "org.cybroid.account") has = true;
        if (ws[j].type === "org.cybroid.today" || ws[j].type === "org.cybroid.launchpad") ours = true;
    }
    // Only CybroidOS's own top bar, and only once.
    if (ours && !has) bar.addWidget("org.cybroid.account");
}
