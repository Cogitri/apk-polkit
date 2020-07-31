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

module tests.apkd_dbus_server.repos;

import apkd.ApkRepository;
import core.stdc.stdlib : exit;
import tests.apkd_test_common.testlib;
import tests.apkd_test_common.apkd_dbus_client;
import gio.c.types : GDBusConnection, BusType, GDBusProxyFlags;
import glib.c.types : GVariant;
import glib.Variant;
import std.file : mkdirRecurse;
import std.path : buildPath;
import std.stdio : File;
import std.string : toStringz;

extern (C) void onNameAppeared(GDBusConnection* connection, const(char)* name,
        const(char)* nameOwner, void* userData)
{
    auto testHelper = cast(TestHelper*) userData;
    GVariant* reposRawVariant = null;

    scope (exit)
    {
        testHelper.cleanup();
    }

    const repoFileDirPath = buildPath(testHelper.apkRootDir, "etc", "apk");
    mkdirRecurse(repoFileDirPath);
    auto repoFile = new File(buildPath(repoFileDirPath, "repositories"), "w");
    repoFile.write("
        http://dl-cdn.alpinelinux.org/alpine/edge/main
        http://dl-cdn.alpinelinux.org/alpine/edge/community
        #http://dl-cdn.alpinelinux.org/alpine/edge/testing
    ");
    repoFile.flush();

    auto apkdHelper = apkd_helper_proxy_new_for_bus_sync(BusType.SYSTEM, GDBusProxyFlags.NONE,
            "dev.Cogitri.apkPolkit.Helper".toStringz(),
            "/dev/Cogitri/apkPolkit/Helper".toStringz(), null, null);
    apkd_helper_set_root(apkdHelper, testHelper.apkRootDir.toStringz);
    assert(apkd_helper_call_list_repositories_sync(apkdHelper, &reposRawVariant, null, null));
    auto reposVariant = new Variant(reposRawVariant);

    ApkRepository[] repoList;
    for (auto i = 0; i < reposVariant.nChildren(); i++)
    {
        auto repo = reposVariant.getChildValue(i);
        size_t len;
        repoList ~= ApkRepository(repo.getChildValue(2).getString(len),
                repo.getChildValue(0).getBoolean());
    }

    assert(repoList.length == 3);
    // dfmt off
    const ApkRepository[] expectedList = [
        ApkRepository("http://dl-cdn.alpinelinux.org/alpine/edge/main", true),
        ApkRepository("http://dl-cdn.alpinelinux.org/alpine/edge/community", true),
        ApkRepository("http://dl-cdn.alpinelinux.org/alpine/edge/testing", false),    
    ];
    //dfmt on
    assert(repoList == expectedList);

    assert(apkd_helper_call_remove_repository_sync(apkdHelper,
            "http://dl-cdn.alpinelinux.org/alpine/edge/main", null, null));

    assert(apkd_helper_call_list_repositories_sync(apkdHelper, &reposRawVariant, null, null));
    reposVariant = new Variant(reposRawVariant);

    repoList = [];
    for (auto i = 0; i < reposVariant.nChildren(); i++)
    {
        auto repo = reposVariant.getChildValue(i);
        size_t len;
        repoList ~= ApkRepository(repo.getChildValue(2).getString(len),
                repo.getChildValue(0).getBoolean());
    }

    assert(repoList.length == 2);
    assert(repoList == expectedList[1 .. $]);

    assert(apkd_helper_call_add_repository_sync(apkdHelper,
            "http://dl-cdn.alpinelinux.org/alpine/edge/main", null, null));

    assert(apkd_helper_call_list_repositories_sync(apkdHelper, &reposRawVariant, null, null));
    reposVariant = new Variant(reposRawVariant);

    repoList = [];
    for (auto i = 0; i < reposVariant.nChildren(); i++)
    {
        auto repo = reposVariant.getChildValue(i);
        size_t len;
        repoList ~= ApkRepository(repo.getChildValue(2).getString(len),
                repo.getChildValue(0).getBoolean());
    }

    assert(repoList.length == 3);
    assert(repoList == expectedList[1 .. $] ~ expectedList[0]);

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
    auto testHelper = TestHelper(args, "dbusServerRepos");
    setupDbusServer(args[3], [
            "dev.Cogitri.apkPolkit.Helper.listRepositories",
            "dev.Cogitri.apkPolkit.Helper.addRepository",
            "dev.Cogitri.apkPolkit.Helper.removeRepository"
            ], &onNameAppeared, &nameVanishedCallback, &testHelper);
    return 0;
}
