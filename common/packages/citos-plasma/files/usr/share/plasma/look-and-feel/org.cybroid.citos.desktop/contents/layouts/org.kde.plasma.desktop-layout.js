// CIT-OS Horizon (citos-plasma): a slim top bar (the CIT-OS mark for
// Launchpad, the app's own menu, tray, clock). Plasma runs this once, when
// someone first signs in.
var bar = new Panel;
bar.location = "top";
bar.height = 2 * Math.floor(gridUnit * 1.7 / 2);
bar.hiding = "none";
bar.floating = false;

// The CIT-OS mark opens Launchpad: every app in one big grid with search
// (also the Meta key, Alt+F1 and the dock's Apps tile).
var launchpad = bar.addWidget("org.cybroid.citos.launchpad");
launchpad.globalShortcut = "Alt+F1";
bar.addWidget("org.kde.plasma.appmenu");
bar.addWidget("org.kde.plasma.panelspacer");
bar.addWidget("org.kde.plasma.systemtray");
var clock = bar.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", "true");
clock.writeConfig("dateDisplayFormat", "BesideTime");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "ddd d MMM");

// The dock is Plank (its icons zoom as the pointer passes), started by
// /etc/xdg/autostart/citos-dock.desktop; Plasma draws only the top bar.

var desks = desktopsForActivity(currentActivity());
for (var i = 0; i < desks.length; i++) {
    desks[i].wallpaperPlugin = "org.kde.image";
    desks[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desks[i].writeConfig("Image", "file:///usr/share/backgrounds/citos/citos-1920x1080.png");
}
