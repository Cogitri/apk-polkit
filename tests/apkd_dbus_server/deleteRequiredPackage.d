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

module tests.apkd_dbus_server.deleteRequiredPackage;

import core.stdc.stdlib : exit;
import tests.apkd_test_common.testlib;
import tests.apkd_test_common.apkd_dbus_client;
import gio.c.types : GDBusConnection, BusType, GDBusProxyFlags;
import glib.c.types : GError;
import glib.GException;
import glib.Variant;
import std.array : split;
import std.conv : to;
import std.file : exists;
import std.format : format;
import std.path : buildPath;
import std.process : execute;
import std.string : strip, toStringz;
import std.stdio;

extern (C) void onNameAppeared(GDBusConnection* connection, const(char)* name,
        const(char)* nameOwner, void* userData)
{
    auto testHelper = cast(TestHelper*) userData;
    GError* error;

    scope (exit)
    {
        testHelper.cleanup();
    }

    auto apkdHelper = apkd_helper_proxy_new_for_bus_sync(BusType.SYSTEM, GDBusProxyFlags.NONE,
            "dev.Cogitri.apkPolkit.Helper".toStringz(),
            "/dev/Cogitri/apkPolkit/Helper".toStringz(), null, null);
    apkd_helper_set_allow_untrusted_repos(apkdHelper, true);
    apkd_helper_set_root(apkdHelper, testHelper.apkRootDir.toStringz());
    auto pkgs = ["test-a".toStringz(), "test-e".toStringz(), null];
    assert(apkd_helper_call_add_packages_sync(apkdHelper, pkgs.ptr, null,
            &error), error.message.to!string);

    auto testA = execute(buildPath(testHelper.apkRootDir, "usr", "bin", "test-a"));

    assert(testA[1].strip() == "hello from test-a-1.0",
            format("Expected 'hello from test-a-1.0', got '%s'", testA[1].strip()));

    pkgs = ["test-a".toStringz(), null];

    assert(!apkd_helper_call_delete_packages_sync(apkdHelper, pkgs.ptr, null, &error));

    const errorMessage = error.message.to!string.split(
            ":")[2] ~ ":" ~ error.message.to!string.split(":")[3];

    assert(errorMessage.strip()
            == "Couldn't delete package due to error package test-a still required by the following packages: test-b test-e");

    assert(buildPath(testHelper.apkRootDir, "usr", "bin", "test-e").exists());

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
    auto testHelper = TestHelper(args, "dbusServerDeleteRequiredPackage");
    setupDbusServer(args[3], [
            "dev.Cogitri.apkPolkit.Helper.addPackages",
            "dev.Cogitri.apkPolkit.Helper.deletePackages"
            ], &onNameAppeared, &nameVanishedCallback, &testHelper);
    return 0;
}
