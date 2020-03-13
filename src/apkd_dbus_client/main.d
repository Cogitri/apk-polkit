module apkd_dbus_client.main;

import apkd_dbus_client.DbusClient;
import apkd_dbus_client.Options;
import std.range : empty;
import std.stdio : writeln;

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
        writeln("0.0.0");
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
    case "delete":
        foreach (packageName; options.packageNames)
        {
            dbusClient.deletePackage(packageName);
        }
        break;
    case "purge":
        foreach (packageName; options.packageNames)
        {
            dbusClient.purgePackage(packageName);
        }
        break;
    case "update":
        dbusClient.update();
        goto case "upgrade";
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
