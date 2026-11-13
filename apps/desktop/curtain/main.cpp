// cybroid-curtain <picture> <marker file>: covers every screen with the
// picture (the new design's wallpaper) while the desktop restarts between
// designs, so there is no black second; fades away when the marker file is
// removed, or after 20 s at most. Run by cybroid-appearance.
#include <QFile>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QTimer>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    if (app.arguments().size() < 3)
        return 2;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("picture"), QUrl::fromLocalFile(app.arguments().at(1)));
    engine.loadFromModule("Cybroid.Curtain", "Main");
    if (engine.rootObjects().isEmpty())
        return 1;
    QObject *root = engine.rootObjects().first();
    const QString marker = app.arguments().at(2);
    QTimer poll;
    poll.setInterval(100);
    QObject::connect(&poll, &QTimer::timeout, &app, [&] {
        if (!QFile::exists(marker)) {
            poll.stop();
            QMetaObject::invokeMethod(root, "finish");
        }
    });
    poll.start();
    QTimer::singleShot(20000, &app, [root] { QMetaObject::invokeMethod(root, "finish"); });
    return app.exec();
}
