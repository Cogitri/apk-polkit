module apkd_dbus_server.main;

static import apkd_dbus_server.globals;
import apkd.SysLogger;
import ddbus;
import ddbus.c_lib : DBusBusType;

import glib.Timeout;
import glib.MainLoop;
import glib.MainContext;
import std.format : format;
import std.stdio : writeln, writefln;
import apkd_dbus_server.DbusServer;
import apkd_dbus_server.Options;

int main(string[] args)
{
    auto options = Options(args);

    if (options.showHelp)
    {
        writeln(helpText);
    }
    else if (options.showVersion)
    {
        writefln("apkd-dbus-server version: %s", apkd_dbus_server.globals.apkdDbusServerVersion);
    }

    LogLevel logLevel;
    switch (options.debugLevel)
    {
    case 0:
        logLevel = LogLevel.error;
        break;
    case -1:
    case 1:
        logLevel = LogLevel.warning;
        break;
    case 2:
        logLevel = LogLevel.info;
        break;
    case 3:
        logLevel = LogLevel.trace;
        break;
    default:
        throw new Exception(format("Invalid debug level %d! Log levels must be between 0 and 3.",
                options.debugLevel));
    }
    setupLogging(logLevel);

    auto dbusConnection = connectToBus(DBusBusType.DBUS_BUS_SYSTEM);
    auto dbusServer = new DBusServer(dbusConnection);
    auto mainContext = new MainContext();
    auto mainLoop = new MainLoop(mainContext, false);
    Timeout.add(20, &dbusLoop, &dbusConnection);
    simpleMainLoop(dbusConnection);
    return 0;
}

extern (C) int dbusLoop(void* data)
{
    auto dbusConnection = cast(Connection*) data;
    (*dbusConnection).tick;
    return true;
}
