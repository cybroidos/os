// CIT-OS Horizon (citos-plasma): a slim top bar (menu, the app's own menu,
// tray, clock) and a floating dock in the centre that steps aside for
// windows. Plasma runs this once, when someone first signs in.
var bar = new Panel;
bar.location = "top";
bar.height = 2 * Math.floor(gridUnit * 1.7 / 2);
bar.hiding = "none";
bar.floating = false;

var menu = bar.addWidget("org.kde.plasma.kickoff");
menu.currentConfigGroup = ["General"];
menu.writeConfig("icon", "citos");
menu.writeConfig("showActionButtonCaptions", "false");
bar.addWidget("org.kde.plasma.appmenu");
bar.addWidget("org.kde.plasma.panelspacer");
bar.addWidget("org.kde.plasma.systemtray");
var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");

var dock = new Panel;
dock.location = "bottom";
dock.height = 2 * Math.floor(gridUnit * 4 / 2);
dock.alignment = "center";
dock.lengthMode = "fit";
dock.hiding = "dodgewindows";
dock.floating = true;
// First, the app grid: every app full screen with search on top (also the
// Meta key and Alt+F1).
var grid = dock.addWidget("org.kde.plasma.kickerdash");
grid.currentConfigGroup = ["General"];
grid.writeConfig("icon", "view-app-grid-symbolic");
grid.globalShortcut = "Alt+F1";
dock.addWidget("org.kde.plasma.marginsseparator");
var tasks = dock.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("iconSpacing", "2");
tasks.writeConfig("maxStripes", "1");
tasks.writeConfig("launchers", [
    "applications:firefox-esr.desktop",
    "applications:org.kde.dolphin.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:org.kde.kwrite.desktop",
    "applications:systemsettings.desktop"
]);

var desks = desktopsForActivity(currentActivity());
for (var i = 0; i < desks.length; i++) {
    desks[i].wallpaperPlugin = "org.kde.image";
    desks[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desks[i].writeConfig("Image", "file:///usr/share/backgrounds/citos/citos-1920x1080.png");
}
