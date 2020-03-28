/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://github.com/Cogitri/apk-polkit).

    apk-polkit is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    apk-polkit is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with apk-polkit.  If not, see <https://www.gnu.org/licenses/>.
*/

module apkd_dbus_client.main;

import apkd_common.ApkDatabaseOperations;
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
        if (options.packageNames == [])
        {
            methodName = "upgradeAllPackages";
        }
        else
        {
            methodName = "upgradePackage";
        }
        break;
    case "list":
        if (options.listInstalled)
        {
            methodName = "listInstalledPackages";
        }
        else if (options.listUpgradable)
        {
            methodName = "listUpgradablePackages";
        }
        else
        {
            methodName = "listAvailablePackages";
        }
        break;
    default:
        assert(0);
    }

    auto dbOp = new ApkDataBaseOperations(methodName);

    auto mainContext = MainContext.default_();
    auto mainLoop = new MainLoop(mainContext, false);
    auto dbusClient = new DBusClient(options.packageNames, dbOp);
    mainLoop.run();
    return 0;
}
