// CybroidOS desktop apps: the system layer under every app's QML (Cybroid.Ui).
// Runs the system's own tools without blocking the window, reads small files,
// knows the standard folders, and follows the design in use (Horizon or Hex,
// Dark or Light, from kdeglobals) so each app changes with the desktop.
#pragma once

#include <QFileSystemWatcher>
#include <QJSValue>
#include <QObject>
#include <QQmlEngine>
#include <QTimer>

class System : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(QString design READ design NOTIFY themeChanged)
    Q_PROPERTY(bool light READ light NOTIFY themeChanged)
    Q_PROPERTY(QString scheme READ scheme NOTIFY themeChanged)

public:
    explicit System(QObject *parent = nullptr);

    QString design() const;
    bool light() const;
    QString scheme() const { return m_scheme; }

    // Runs args (no shell) and calls done(output, exitCode) when it ends.
    Q_INVOKABLE void run(const QStringList &args, const QJSValue &done = QJSValue());
    // Starts an app on its own (KDE's settings pages, a photo viewer).
    Q_INVOKABLE void launch(const QStringList &args);
    Q_INVOKABLE QString readText(const QString &path) const;
    Q_INVOKABLE bool exists(const QString &path) const;
    Q_INVOKABLE bool makeDir(const QString &path) const;
    // "pictures", "videos", "home", "config"
    Q_INVOKABLE QString folder(const QString &which) const;
    // The newest files in the folders matching the name filters, newest first.
    Q_INVOKABLE QStringList newest(const QStringList &dirs, const QStringList &filters, int count) const;

Q_SIGNALS:
    void themeChanged();

private:
    void reread();
    QString m_scheme;
    QString m_config;
    QFileSystemWatcher m_watch;
    QTimer m_later;
};
