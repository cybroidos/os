// One window per app: a second start hands its argument (a page) to the
// first and ends; the first calls its window's showPage(argument).
#pragma once

#include <QGuiApplication>
#include <QLocalServer>
#include <QLocalSocket>
#include <QObject>
#include <QQmlApplicationEngine>
#include <QWindow>
#include <unistd.h>

namespace cybroid {

inline QString instanceName(const QString &app)
{
    return QStringLiteral("%1-%2").arg(app).arg(getuid());
}

// True when another copy is running and took the argument.
inline bool handedToRunning(const QString &app, const QString &arg)
{
    QLocalSocket other;
    other.connectToServer(instanceName(app));
    if (!other.waitForConnected(300))
        return false;
    other.write(arg.toUtf8() + '\n');
    other.waitForBytesWritten(300);
    other.disconnectFromServer();
    return true;
}

inline void listenForOthers(const QString &app, QQmlApplicationEngine *engine)
{
    QLocalServer::removeServer(instanceName(app));
    auto *server = new QLocalServer(engine);
    server->listen(instanceName(app));
    QObject::connect(server, &QLocalServer::newConnection, engine, [server, engine] {
        QLocalSocket *c = server->nextPendingConnection();
        if (!c)
            return;
        QObject::connect(c, &QLocalSocket::readyRead, engine, [c, engine] {
            const QString arg = QString::fromUtf8(c->readAll()).trimmed();
            c->disconnectFromServer();
            c->deleteLater();
            if (engine->rootObjects().isEmpty())
                return;
            QObject *root = engine->rootObjects().first();
            QMetaObject::invokeMethod(root, "showPage", Q_ARG(QVariant, arg));
            if (auto *w = qobject_cast<QWindow *>(root)) {
                w->show();
                w->raise();
                w->requestActivate();
            }
        });
    });
}

} // namespace cybroid
