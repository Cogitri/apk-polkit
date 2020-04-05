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

import apkd.ApkPackage;
import apkd_common.ApkDatabaseOperations;
static import apkd_common.globals;
import apkd_dbus_client.DbusClient;
import apkd_dbus_client.Options;
import core.stdc.stdlib : exit;
import gio.c.types;
import gio.Task;
import glib.GException;
import glib.MainContext;
import glib.MainLoop;
import glib.Variant;
import std.datetime;
import std.experimental.logger;
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

    auto dbOp = ApkDataBaseOperations(methodName);

    auto mainContext = MainContext.default_();
    auto mainLoop = new MainLoop(mainContext, false);
    auto dbusClient = DBusClient.get();
    dbusClient.setProperty(new Variant(true), null);
    dbusClient.queryAsync(options.packageNames, dbOp, null, &checkAuth, &dbOp);
    mainLoop.run();
    return 0;
}

extern (C) void checkAuth(GObject*, GAsyncResult* res, void* userData)
{
    Variant* dbusRes;
    try
    {
        dbusRes = DBusClient.queryFinish(res);
    }
    catch (GException e)
    {
        error(e);
        exit(1);
    }

    auto dbOp = cast(ApkDataBaseOperations*) userData;

    // For some DBus calls we get a return value (other than errors)
    switch (dbOp.val) with (ApkDataBaseOperations.Enum)
    {
    case listAvailablePackages:
    case listInstalledPackages:
    case listUpgradablePackages:
        auto dbusRet = dbusRes.getChildValue(0);
        ApkPackage[] pkgArr;

        for (uint i; i < dbusRet.nChildren(); i++)
        {
            auto valueTuple = dbusRet.getChildValue(i);
            ulong len;

            // dfmt off
                auto pkg = ApkPackage(
                        valueTuple.getChildValue(0).getString(len),
                        valueTuple.getChildValue(1).getString(len),
                        valueTuple.getChildValue(2).getString(len),
                        valueTuple.getChildValue(3).getString(len),
                        valueTuple.getChildValue(4).getString(len),
                        valueTuple.getChildValue(5).getString(len),
                        valueTuple.getChildValue(6).getString(len),
                        valueTuple.getChildValue(7).getString(len),
                        valueTuple.getChildValue(8).getString(len),
                        valueTuple.getChildValue(9).getString(len),
                        valueTuple.getChildValue(10).getString(len),
                        valueTuple.getChildValue(11).getUint64(),
                        valueTuple.getChildValue(12).getUint64(),
                        SysTime(0), //FIXME
                    );
                // dfmt on
            pkgArr ~= pkg;
        }

        foreach (pkg; pkgArr)
        {
            writeln(pkg);
        }

        break;
    default:
    }

    exit(0);
}
