// CybroidOS Settings: cybroid-settings [wifi|sound|appearance|datetime|about|...]
// cybroid-settings welcome: the first-run welcome (Welcome.qml), its own window.
#include <QGuiApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "singleinstance.h"

int main(int argc, char *argv[])
{
    // Our own controls are drawn in QML; the plain style keeps KDE's
    // desktop style from drawing under them.
    QQuickStyle::setStyle(QStringLiteral("Basic"));
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("cybroid-settings"));
    app.setApplicationDisplayName(QStringLiteral("Settings"));
    app.setDesktopFileName(QStringLiteral("cybroid-settings"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("preferences-system")));

    const QString page = app.arguments().size() > 1 ? app.arguments().at(1) : QString();
    const bool welcome = page == QStringLiteral("welcome");
    const QString instance = welcome ? QStringLiteral("cybroid-welcome") : QStringLiteral("cybroid-settings");
    if (welcome) {
        app.setApplicationDisplayName(QStringLiteral("Welcome"));
        app.setDesktopFileName(QStringLiteral("cybroid-welcome"));
        app.setWindowIcon(QIcon::fromTheme(QStringLiteral("cybroid-mark")));
    }
    if (cybroid::handedToRunning(instance, page))
        return 0;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), page.isEmpty() ? QStringLiteral("wifi") : page);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Cybroid.Settings", welcome ? "Welcome" : "Main");
    cybroid::listenForOthers(instance, &engine);
    return app.exec();
}
