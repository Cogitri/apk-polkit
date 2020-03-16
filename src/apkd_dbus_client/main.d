module apkd_dbus_client.main;

import apkd_dbus_client.DbusClient;
import apkd_dbus_client.Options;
static import apkd_dbus_client.globals;
import glib.MainContext;
import glib.MainLoop;
import std.range : empty;
import std.stdio : writeln, writefln;

int main(string[] args)
{
    auto options = Options(args);

    if (options.showHelp)
    {
        writeln(helpText);
        return 0;
    }
    else if (options.showVersion)
    {
        writefln("apkd version: %s", apkd_dbus_client.globals.apkdDbusClientVersion);
        return 0;
    }

    string methodName;

    switch (options.mode)
    {
    case "add":
        methodName = "addPackage";
        break;
    case "delete":
        methodName = "deletePackage";
        break;
    case "update":
        methodName = "updateRepositories";
        break;
    case "upgrade":
        methodName = "upgradePackage";
        break;
    default:
        assert(0);
    }

    auto mainContext = MainContext.default_();
    auto mainLoop = new MainLoop(mainContext, false);
    auto dbusClient = new DBusClient(options.packageNames, methodName);
    mainLoop.run();
    return 0;
}
