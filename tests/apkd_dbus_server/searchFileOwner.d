/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://gitlab.alpinelinux.org/Cogitri/apk-polkit).

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

module tests.apkd_dbus_server.searchFileOwner;

import apkd.ApkPackage;
import core.stdc.stdlib : exit;
import tests.apkd_test_common.testlib;
import tests.apkd_test_common.apkd_dbus_client;
import gio.c.types : GDBusConnection, BusType, GDBusProxyFlags;
import glib.GException;
import glib.Variant;
import std.datetime : SysTime;
import std.string : toStringz;

extern (C) void onNameAppeared(GDBusConnection* connection, const(char)* name,
        const(char)* nameOwner, void* userData)
{
    auto testHelper = cast(TestHelper*) userData;

    scope (exit)
    {
        testHelper.cleanup();
    }

    auto apkdHelper = apkd_helper_proxy_new_for_bus_sync(BusType.SYSTEM, GDBusProxyFlags.NONE,
            "dev.Cogitri.apkPolkit.Helper".toStringz(),
            "/dev/Cogitri/apkPolkit/Helper".toStringz(), null, null);
    apkd_helper_set_root(apkdHelper, testHelper.apkRootDir.toStringz());
    apkd_helper_set_allow_untrusted_repos(apkdHelper, true);
    auto pkgs = ["test-a".toStringz(), null];
    apkd_helper_call_add_packages_sync(apkdHelper, pkgs.ptr, null, null);
    auto path = "/usr/bin/test-a";
    GVariant* dbusRes;
    assert(apkd_helper_call_search_file_owner_sync(apkdHelper,
            path.toStringz(), &dbusRes, null, null));
    auto valueTuple = new Variant(dbusRes);

    size_t len;
    const pkgname = valueTuple.getChildValue(0).getString(len);
    assert(pkgname == "test-a");

    testHelper.cleanup();
    exit(0);
}

extern extern (C) __gshared bool rt_trapExceptions;
extern extern (C) int _d_run_main(int, char**, void*);

extern (C) int main(int argc, char** argv)
{
    rt_trapExceptions = false;
    return _d_run_main(argc, argv, &_main);
}

int _main(string[] args)
{
    auto testHelper = TestHelper(args, "dbusServerSearchFileOwner");
    setupDbusServer(args[3], [
            "dev.Cogitri.apkPolkit.Helper.addPackages",
            "dev.Cogitri.apkPolkit.Helper.searchFileOwner",
            ], &onNameAppeared, &nameVanishedCallback, &testHelper);
    return 0;
}
