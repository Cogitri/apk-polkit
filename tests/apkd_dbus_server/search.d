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

module tests.apkd_dbus_client.search;

import apkd.ApkPackage;
import apkd_common.ApkDataBaseOperations;
import apkd_common.DBusPropertyOperations;
import apkd_dbus_client.DbusClient;
import core.stdc.stdlib : exit;
import tests.apkd_test_common.testlib;
import gio.c.types : GDBusConnection;
import glib.Variant;
import std.datetime : SysTime;
import std.stdio;

extern (C) void onNameAppeared(GDBusConnection* connection, const(char)* name,
        const(char)* nameOwner, void* userData)
{
    auto testHelper = cast(TestHelper*) userData;

    auto client = DBusClient.get();
    client.setProperty(new DBusPropertyOperations(DBusPropertyOperations.Enum.root,
            DBusPropertyOperations.DirectionEnum.set), new Variant(testHelper.apkRootDir), null);
    client.setProperty(new DBusPropertyOperations(DBusPropertyOperations.Enum.allowUntrustedRepos,
            DBusPropertyOperations.DirectionEnum.set), new Variant(true), null);
    client.querySync([],
            new ApkDataBaseOperations(ApkDataBaseOperations.Enum.updateRepositories), null);
    auto dbusRes = client.querySync(["test"],
            new ApkDataBaseOperations(ApkDataBaseOperations.Enum.searchForPackages), null);
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
    assert(pkgArr.length == 5);
    exit(0);
}

int main(string[] args)
{
    auto testHelper = TestHelper(args, "dbusServerSearch");
    setupDbusServer(args[4], [
            new ApkDataBaseOperations(ApkDataBaseOperations.Enum.searchForPackages).toPolkitAction(),
            new ApkDataBaseOperations(ApkDataBaseOperations.Enum.updateRepositories)
            .toPolkitAction()
            ], &onNameAppeared, &nameVanishedCallback, &testHelper);
    return 0;
}
