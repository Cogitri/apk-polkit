module apkd_dbus_server.main;

static import apkd_common.globals;
import apkd_common.SysLogger;

import glib.MainLoop;
import glib.Timeout;
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
        writefln("apkd-dbus-server version: %s", apkd_common.globals.apkdVersion);
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

    auto mainContext = MainContext.default_();
    auto mainLoop = new MainLoop(mainContext, false);
    auto dbusServer = new DBusServer();
    mainLoop.run();
    return 0;
}
