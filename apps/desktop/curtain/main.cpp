// cybroid-curtain <picture> <marker file>: covers every screen with the
// picture (the new design's wallpaper) while the desktop changes between
// designs and restarts, so there is no black second and no half-changed
// desktop. Once the picture is fully shown it writes <marker>.shown (the
// caller waits for it before changing anything); it fades away when the
// marker file is removed, or after 20 s at most. Run by cybroid-appearance.
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
    poll.setInterval(50);
    bool told = false;
    QObject::connect(&poll, &QTimer::timeout, &app, [&] {
        if (!told && root->property("covered").toBool()) {
            told = true;
            QFile f(marker + QStringLiteral(".shown"));
            f.open(QIODevice::WriteOnly);
        }
        if (!QFile::exists(marker)) {
            poll.stop();
            QMetaObject::invokeMethod(root, "finish");
        }
    });
    poll.start();
    QTimer::singleShot(20000, &app, [root] { QMetaObject::invokeMethod(root, "finish"); });
    return app.exec();
}
