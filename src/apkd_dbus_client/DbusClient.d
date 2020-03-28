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

module libapkd_dbus_client.DbusClient;

import apkd.ApkPackage;
import apkd_common.ApkDatabaseOperations;
static import apkd_common.globals;
import core.stdc.stdlib : exit;
import gio.c.types : BusType, BusNameWatcherFlags, DBusCallFlags, G_MAXINT32;
import gio.DBusNames;
import gio.DBusConnection;
import glib.Variant;
import glib.VariantType;
import std.conv;
import std.datetime;
import std.exception;
import std.stdio : writeln;

struct DBusClientUserData
{
    string[] packageNames;
    ApkDataBaseOperations dbOp;
}

class DBusClient
{
    this(string[] packageNames, ApkDataBaseOperations dbOp)
    {
        this.data = DBusClientUserData(packageNames, dbOp);
        this.watcherId = DBusNames.watchName(BusType.SYSTEM, apkd_common.globals.dbusBusName,
                BusNameWatcherFlags.AUTO_START, &onNameAppeared,
                &onNameDisappeared, &this.data, null);
    }

    extern (C) static void onNameAppeared(GDBusConnection* rawConnection,
            const char* name, const char* nameOwner, void* data)
    {
        auto dbusConnection = new DBusConnection(rawConnection);
        auto userData = cast(DBusClientUserData*) data;
        enforce(userData !is null);

        bool dbusOpSucessfull;

        switch (userData.dbOp.val) with (ApkDataBaseOperations.Enum)
        {
        case updateRepositories:
        case upgradeAllPackages:
            auto dbusRet = dbusConnection.callSync(apkd_common.globals.dbusBusName, apkd_common.globals.dbusObjectPath,
                    apkd_common.globals.dbusInterfaceName, userData.dbOp.to!string, null,
                    new VariantType("(b)"), DBusCallFlags.NONE, G_MAXINT32, null);
            dbusOpSucessfull = dbusRet.getChildValue(0).getBoolean();
            break;
        case listAvailablePackages:
        case listInstalledPackages:
        case listUpgradablePackages:
            auto dbusTupleRet = dbusConnection.callSync(apkd_common.globals.dbusBusName,
                    apkd_common.globals.dbusObjectPath,
                    apkd_common.globals.dbusInterfaceName, userData.dbOp.to!string, null,
                    new VariantType("(a(ssssssssssstt))"), DBusCallFlags.NONE, G_MAXINT32, null);
            auto dbusRet = dbusTupleRet.getChildValue(0);

            auto arrLen = dbusRet.nChildren();
            if (arrLen > 0)
            {
                dbusOpSucessfull = true;
            }
            else
            {
                dbusOpSucessfull = false;
            }

            ApkPackage[] pkgArr;
            for (uint i; i < arrLen; i++)
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
            auto parameters = new Variant(userData.packageNames);
            auto dbusRet = dbusConnection.callSync(apkd_common.globals.dbusBusName, apkd_common.globals.dbusObjectPath,
                    apkd_common.globals.dbusInterfaceName, userData.dbOp.to!string,
                    new Variant([parameters]), new VariantType("(b)"),
                    DBusCallFlags.NONE, 1000, null);
            dbusOpSucessfull = dbusRet.getChildValue(0).getBoolean();
        }

        if (dbusOpSucessfull)
        {
            exit(0);
        }
        else
        {
            exit(1);
        }
    }

    extern (C) static void onNameDisappeared(GDBusConnection* connection, const char* name, void*)
    {
    }

private:
    uint watcherId;
    DBusClientUserData data;
}
