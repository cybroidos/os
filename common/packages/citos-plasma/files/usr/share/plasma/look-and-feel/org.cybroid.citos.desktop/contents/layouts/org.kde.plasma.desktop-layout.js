// CIT-OS Horizon (citos-plasma): a slim top bar (the CIT-OS mark for
// Launchpad, the app's own menu, tray, Control Centre, the clock). Plasma
// runs this once, when someone first signs in.
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
var tray = bar.addWidget("org.kde.plasma.systemtray");
// The tray keeps only what Control Centre doesn't show, and each of those
// only while it has something to say: notifications (they bring up their own
// pop-ups), a USB drive while one is plugged in, the battery on laptops, the
// keyboard layout when there are two, what's playing, a camera in use. Wi-Fi,
// sound and brightness live in Control Centre. Items left out of the known
// list would be added by Plasma later, so every one is named.
var trayContainment = desktopById(tray.readConfig("SystrayContainmentId"));
if (trayContainment) {
    trayContainment.currentConfigGroup = ["General"];
    trayContainment.writeConfig("extraItems", [
        "org.kde.plasma.notifications", "org.kde.plasma.devicenotifier", "org.kde.plasma.battery",
        "org.kde.plasma.keyboardlayout", "org.kde.plasma.mediacontroller", "org.kde.plasma.cameraindicator"]);
    trayContainment.writeConfig("knownItems", [
        "org.kde.plasma.notifications", "org.kde.plasma.devicenotifier", "org.kde.plasma.battery",
        "org.kde.plasma.keyboardlayout", "org.kde.plasma.mediacontroller", "org.kde.plasma.cameraindicator",
        "org.kde.plasma.volume", "org.kde.plasma.brightness", "org.kde.plasma.networkmanagement",
        "org.kde.plasma.bluetooth", "org.kde.kscreen", "org.kde.plasma.clipboard",
        "org.kde.plasma.keyboardindicator", "org.kde.plasma.manage-inputmethod", "org.kde.plasma.printmanager",
        "org.kde.plasma.vault", "org.kde.kdeconnect", "org.kde.plasma.weather", "org.kde.plasma.nightcolorcontrol",
        "org.kde.plasma.kclock_1x2", "org.kde.plasma.mediacontroller"]);
    trayContainment.writeConfig("hiddenItems", ["org.kde.plasma.notifications"]);
}
// Control Centre (network, Tower, Do Not Disturb, sound), then the date and
// time, which opens notifications and the Today widgets, as on macOS.
bar.addWidget("org.cybroid.citos.controlcentre");
bar.addWidget("org.cybroid.citos.today");

// The dock is Plank (its icons zoom as the pointer passes), started by
// /etc/xdg/autostart/citos-dock.desktop; Plasma draws only the top bar.

var desks = desktopsForActivity(currentActivity());
for (var i = 0; i < desks.length; i++) {
    desks[i].wallpaperPlugin = "org.kde.image";
    desks[i].currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
    desks[i].writeConfig("Image", "file:///usr/share/backgrounds/citos/citos-1920x1080.png");
    // The design's cards on the desktop: Today at the left, this computer
    // (memory, disk, Tower) at the right.
    var g = screenGeometry(desks[i].screen);
    var today = desks[i].addWidget("org.cybroid.citos.widgets", 40, 56, 300, 176);
    today.currentConfigGroup = ["General"];
    today.writeConfig("card", "today");
    var sys = desks[i].addWidget("org.cybroid.citos.widgets", g.width - 300 - 40, 56, 300, 176);
    sys.currentConfigGroup = ["General"];
    sys.writeConfig("card", "system");
    // The desktop keeps widget places in its saved geometry; positions given
    // to addWidget last only until the shell restarts, after which both
    // cards fell into the top-left corner. Save them there too.
    var places = "Applet-" + today.id + ":40,56,300,176,0;" +
        "Applet-" + sys.id + ":" + (g.width - 300 - 40) + ",56,300,176,0;";
    desks[i].currentConfigGroup = [];
    desks[i].writeConfig("ItemGeometries-" + g.width + "x" + g.height, places);
    desks[i].writeConfig("ItemGeometriesHorizontal", places);
}
