#include "system.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusReply>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QProcess>
#include <QStandardPaths>

#include <algorithm>
#include <memory>

namespace {
QString kdeScheme(const QString &config)
{
    // [General] ColorScheme in kdeglobals, read by hand: QSettings takes a
    // [General] group as its top level and KDE's file has more than ini.
    QFile f(config + QStringLiteral("/kdeglobals"));
    if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        bool general = false;
        while (!f.atEnd()) {
            const QString line = QString::fromUtf8(f.readLine()).trimmed();
            if (line.startsWith(QLatin1Char('[')))
                general = line == QLatin1String("[General]");
            else if (general && line.startsWith(QLatin1String("ColorScheme=")))
                return line.mid(12);
        }
    }
    return QStringLiteral("CybroidHorizon");
}
} // namespace

System::System(QObject *parent)
    : QObject(parent)
    , m_config(QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation))
{
    m_scheme = kdeScheme(m_config);
    // kdeglobals is replaced, not written in place: the folder is watched,
    // and a short wait lets a theme change finish writing.
    m_later.setSingleShot(true);
    m_later.setInterval(300);
    connect(&m_later, &QTimer::timeout, this, &System::reread);
    m_watch.addPath(m_config);
    connect(&m_watch, &QFileSystemWatcher::directoryChanged, &m_later, qOverload<>(&QTimer::start));
}

void System::reread()
{
    const QString s = kdeScheme(m_config);
    if (s != m_scheme) {
        m_scheme = s;
        Q_EMIT themeChanged();
    }
}

QString System::design() const
{
    return m_scheme.contains(QLatin1String("Hex")) ? QStringLiteral("hex") : QStringLiteral("horizon");
}

bool System::light() const
{
    return m_scheme.endsWith(QLatin1String("Light"));
}

void System::run(const QStringList &args, const QJSValue &done)
{
    if (args.isEmpty())
        return;
    auto *p = new QProcess(this);
    p->setProcessChannelMode(QProcess::MergedChannels);
    auto finish = [p, done](int code) {
        const QString out = QString::fromUtf8(p->readAll());
        p->deleteLater();
        if (done.isCallable())
            QJSValue(done).call({QJSValue(out), QJSValue(code)});
    };
    connect(p, &QProcess::finished, this, [finish](int code, QProcess::ExitStatus) { finish(code); });
    connect(p, &QProcess::errorOccurred, this, [p, finish](QProcess::ProcessError e) {
        if (e == QProcess::FailedToStart)
            finish(127);
    });
    p->start(args.first(), args.mid(1));
}

void System::launch(const QStringList &args)
{
    if (!args.isEmpty())
        QProcess::startDetached(args.first(), args.mid(1));
}

QString System::readText(const QString &path) const
{
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly))
        return {};
    return QString::fromUtf8(f.readAll());
}

bool System::exists(const QString &path) const
{
    return QFileInfo::exists(path);
}

bool System::makeDir(const QString &path) const
{
    return QDir().mkpath(path);
}

QString System::folder(const QString &which) const
{
    if (which == QLatin1String("pictures"))
        return QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (which == QLatin1String("videos"))
        return QStandardPaths::writableLocation(QStandardPaths::MoviesLocation);
    if (which == QLatin1String("config"))
        return m_config;
    return QDir::homePath();
}

QStringList System::newest(const QStringList &dirs, const QStringList &filters, int count) const
{
    QFileInfoList all;
    for (const QString &d : dirs)
        all += QDir(d).entryInfoList(filters, QDir::Files);
    std::sort(all.begin(), all.end(), [](const QFileInfo &a, const QFileInfo &b) { return a.lastModified() > b.lastModified(); });
    QStringList out;
    for (const QFileInfo &fi : std::as_const(all)) {
        if (out.size() >= count)
            break;
        out << fi.absoluteFilePath();
    }
    return out;
}

using NMSettings = QMap<QString, QVariantMap>;
Q_DECLARE_METATYPE(NMSettings)

void System::joinWifi(const QString &ssid, const QString &password, const QString &security, const QJSValue &done)
{
    static const bool registered = [] { qDBusRegisterMetaType<NMSettings>(); return true; }();
    Q_UNUSED(registered)
    auto reply = [done](bool ok, const QString &message) {
        if (done.isCallable())
            QJSValue(done).call({QJSValue(ok), QJSValue(message)});
    };
    const QString nm = QStringLiteral("org.freedesktop.NetworkManager");
    QDBusInterface manager(nm, QStringLiteral("/org/freedesktop/NetworkManager"), nm, QDBusConnection::systemBus());
    // The first Wi-Fi device (NM_DEVICE_TYPE_WIFI = 2).
    QDBusReply<QList<QDBusObjectPath>> devices = manager.call(QStringLiteral("GetDevices"));
    QDBusObjectPath wifi;
    for (const QDBusObjectPath &d : devices.value()) {
        QDBusInterface dev(nm, d.path(), QStringLiteral("org.freedesktop.NetworkManager.Device"), QDBusConnection::systemBus());
        if (dev.property("DeviceType").toUInt() == 2) {
            wifi = d;
            break;
        }
    }
    if (wifi.path().isEmpty()) {
        reply(false, QStringLiteral("No Wi-Fi device"));
        return;
    }
    NMSettings settings;
    settings[QStringLiteral("connection")] = {{QStringLiteral("id"), ssid}, {QStringLiteral("type"), QStringLiteral("802-11-wireless")}};
    settings[QStringLiteral("802-11-wireless")] = {{QStringLiteral("ssid"), ssid.toUtf8()}, {QStringLiteral("mode"), QStringLiteral("infrastructure")}};
    if (!security.isEmpty())
        settings[QStringLiteral("802-11-wireless-security")] = {{QStringLiteral("key-mgmt"), security}, {QStringLiteral("psk"), password}};
    QDBusPendingCall call = manager.asyncCall(QStringLiteral("AddAndActivateConnection"), QVariant::fromValue(settings),
                                              QVariant::fromValue(wifi), QVariant::fromValue(QDBusObjectPath(QStringLiteral("/"))));
    auto *watcher = new QDBusPendingCallWatcher(call, this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, watcher, reply, nm] {
        QDBusPendingReply<QDBusObjectPath, QDBusObjectPath> r = *watcher;
        watcher->deleteLater();
        if (r.isError()) {
            reply(false, r.error().message());
            return;
        }
        // NetworkManager has only started: wait for the connection to come
        // up (ActiveConnection State 2) or fail (4, or 30 s), and on failure
        // remove the half-made network, so a wrong password isn't kept.
        const QString settingsPath = r.argumentAt<0>().path(), activePath = r.argumentAt<1>().path();
        auto *poll = new QTimer(this);
        auto tries = std::make_shared<int>(0);
        poll->setInterval(500);
        connect(poll, &QTimer::timeout, this, [poll, tries, reply, nm, settingsPath, activePath] {
            QDBusInterface active(nm, activePath, QStringLiteral("org.freedesktop.NetworkManager.Connection.Active"), QDBusConnection::systemBus());
            const QVariant st = active.property("State");
            const uint state = st.isValid() ? st.toUInt() : 4;    // gone: it failed
            if (state == 2 || state == 4 || ++*tries > 60) {
                poll->stop();
                poll->deleteLater();
                if (state == 2) {
                    reply(true, QString());
                    return;
                }
                QDBusInterface conn(nm, settingsPath, QStringLiteral("org.freedesktop.NetworkManager.Settings.Connection"), QDBusConnection::systemBus());
                conn.call(QStringLiteral("Delete"));
                reply(false, QStringLiteral("secrets were required or wrong"));
            }
        });
        poll->start();
    });
}
