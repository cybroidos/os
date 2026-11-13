// CybroidOS Camera: cybroid-camera [photo|video]
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
    app.setApplicationName(QStringLiteral("cybroid-camera"));
    app.setApplicationDisplayName(QStringLiteral("Camera"));
    app.setDesktopFileName(QStringLiteral("cybroid-camera"));
    app.setWindowIcon(QIcon::fromTheme(QStringLiteral("camera-photo")));

    const QString page = app.arguments().size() > 1 ? app.arguments().at(1) : QString();
    if (cybroid::handedToRunning(QStringLiteral("cybroid-camera"), page))
        return 0;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("startPage"), page.isEmpty() ? QStringLiteral("photo") : page);
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Cybroid.Camera", "Main");
    cybroid::listenForOthers(QStringLiteral("cybroid-camera"), &engine);
    return app.exec();
}
