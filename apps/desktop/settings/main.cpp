// CybroidOS Settings: cybroid-settings [wifi|sound|appearance|datetime|about]
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
    if (cybroid::handedToRunning(QStringLiteral("cybroid-settings"), page))
        return 0;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), page.isEmpty() ? QStringLiteral("wifi") : page);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Cybroid.Settings", "Main");
    cybroid::listenForOthers(QStringLiteral("cybroid-settings"), &engine);
    return app.exec();
}
