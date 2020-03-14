module apkd_dbus_client.main;

import apkd_dbus_client.DbusClient;
import apkd_dbus_client.Options;
static import apkd_dbus_client.globals;
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

    auto dbusClient = new DBusClient();

    switch (options.mode)
    {
    case "add":
        foreach (packageName; options.packageNames)
        {
            dbusClient.addPackage(packageName);
        }
        break;
    case "del":
        foreach (packageName; options.packageNames)
        {
            dbusClient.deletePackage(packageName);
        }
        break;
    case "update":
        dbusClient.update();
        break;
    case "upgrade":
        if (options.packageNames.empty)
        {
            dbusClient.upgradeAll();
        }
        else
        {
            foreach (packageName; options.packageNames)
            {
                dbusClient.upgrade(packageName);
            }
        }
        break;
    default:
        assert(0);
    }

    return 0;
}
