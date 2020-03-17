module apkd_dbus_client.main;

static import apkd_common.globals;
import apkd_dbus_client.DbusClient;
import apkd_dbus_client.Options;
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
        writefln("apkd version: %s", apkd_common.globals.apkdVersion);
        return 0;
    }

    string methodName;

    switch (options.mode)
    {
    case "add":
        methodName = "addPackage";
        break;
    case "del":
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
