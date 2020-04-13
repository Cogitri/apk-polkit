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

module tests.apkd_dbus_client.update;

import apkd_common.ApkDataBaseOperations;
import apkd_common.DBusPropertyOperations;
import core.stdc.stdlib : exit;
import tests.apkd_test_common.testlib;
import tests.apkd_test_common.apkd_dbus_client;
import gio.c.types : GDBusConnection, BusType, GDBusProxyFlags;
import std.exception : enforce;
import std.string : toStringz;

extern (C) void onNameAppeared(GDBusConnection* connection, const(char)* name,
        const(char)* nameOwner, void* userData)
{
    auto testHelper = cast(TestHelper*) userData;

    auto apkdHelper = apkd_helper_proxy_new_for_bus_sync(BusType.SYSTEM, GDBusProxyFlags.NONE,
            "dev.Cogitri.apkPolkit.Helper".toStringz(),
            "/dev/Cogitri/apkPolkit/Helper".toStringz(), null, null);
    apkd_helper_set_allow_untrusted_repos(apkdHelper, true);
    apkd_helper_set_root(apkdHelper, testHelper.apkRootDir.toStringz);
    enforce(apkd_helper_call_update_repositories_sync(apkdHelper, null, null));
    exit(0);
}

int main(string[] args)
{
    auto testHelper = TestHelper(args, "dbusServerUpdate");
    setupDbusServer(args[4], [
            new ApkDataBaseOperations(ApkDataBaseOperations.Enum.updateRepositories)
            .toPolkitAction()
            ], &onNameAppeared, &nameVanishedCallback, &testHelper);
    return 0;
}
