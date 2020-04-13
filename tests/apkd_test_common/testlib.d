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

module tests.testlib;

import core.thread.osthread : Thread;
import core.stdc.stdlib : exit;
import deimos.apk_toolsd.apk_defines;
import gio.DBusNames;
import gio.DBusProxy;
import gio.TestDBus;
import glib.MainContext;
import glib.MainLoop;
import glib.Variant;
import std.conv : to;
import std.datetime : dur;
import std.exception;
import std.format;
import std.path : buildPath;
import std.process;
import std.stdio : stderr, writefln;

struct TestHelper
{
    @disable this();

    this(string[] args, string testAppletName, bool allowUntrusted = true)
    {
        this.apkRootDir = format("%s-%s", args[1], testAppletName);
        auto abuildBuildDir = format("%s-%s", args[2], testAppletName);
        this.repoDir = buildPath(abuildBuildDir, "abuilds");
        if (allowUntrusted)
        {
            apk_flags = APK_ALLOW_UNTRUSTED;
        }
        apk_verbosity = 2;

        auto runScript = execute([args[3], this.apkRootDir, abuildBuildDir]);
        enforce(runScript[0] == 0, runScript[1]);
    }

    ~this()
    {
        execute(["rm", "-rf", this.apkRootDir]);
        execute(["rm", "-rf", this.repoDir]);
    }

    string apkRootDir;
    string repoDir;
}

extern (C) void nameVanishedCallback(GDBusConnection*, const(char)* name, void*)
{
    stderr.writefln("Bail-Out! Lost name %s", name.to!string);
    exit(1);
}

void setupDbusServer(string dbusServerPath, string[] polkitActions, GBusNameAppearedCallback nameAppearedCallback,
        GBusNameVanishedCallback nameVanishedCallback = &nameVanishedCallback, void* userData = null)
{
    auto tester = new TestDBus(GTestDBusFlags.NONE);
    tester.up();
    // TestDBus only sets DBUS_SESSION_BUS_ADDRESS
    environment["DBUS_SYSTEM_BUS_ADDRESS"] = tester.getBusAddress();

    auto dbusMockPid = spawnProcess([
            "python3", "-m", "dbusmock", "--template", "polkitd"
            ], ["DBUS_SYSTEM_BUS_ADDRESS": tester.getBusAddress()]);
    // Wait for dbusmock to start...
    Thread.sleep(dur!("seconds")(1));

    auto dbusServerPid = spawnProcess([dbusServerPath, "--debug=3"],
            ["DBUS_SYSTEM_BUS_ADDRESS": tester.getBusAddress()]);
    scope (exit)
    {
        dbusMockPid.kill();
        dbusServerPid.kill();
        tester.down();
    }
    Thread.sleep(dur!("seconds")(1));

    auto proxy = new DBusProxy(BusType.SYSTEM, DBusProxyFlags.DO_NOT_AUTO_START, null, "org.freedesktop.PolicyKit1",
            "/org/freedesktop/PolicyKit1/Authority", "org.freedesktop.PolicyKit1.Authority", null);
    Variant[] permittedActions;
    foreach (action; polkitActions)
    {
        permittedActions ~= new Variant(action);
    }
    proxy.callSync("org.freedesktop.DBus.Mock.SetAllowed",
            new Variant([
                    new Variant([
                        new Variant("dev.Cogitri.apkPolkit.Helper.getAllProperties"),
                        new Variant("dev.Cogitri.apkPolkit.Helper.setAllowUntrustedRepos"),
                        new Variant("dev.Cogitri.apkPolkit.Helper.setRoot"),
                        new Variant("dev.Cogitri.apkPolkit.Helper.setAllowUntrustedRepos"),
                    ] ~ permittedActions)
                ]), GDBusCallFlags.NO_AUTO_START, 1000, null);

    DBusNames.watchName(GBusType.SYSTEM, "dev.Cogitri.apkPolkit.Helper",
            GBusNameWatcherFlags.NONE, nameAppearedCallback, nameVanishedCallback, userData, null);
    auto mainContext = MainContext.default_();
    auto mainLoop = new MainLoop(mainContext, false);
    mainLoop.run();
}
