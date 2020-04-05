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

import apkd_common.ApkDatabaseOperations;
static import apkd_common.globals;
import gio.AsyncResultIF;
import gio.c.types : BusType, BusNameWatcherFlags, DBusCallFlags, G_MAXINT32, GDBusProxy;
import gio.Cancellable;
import gio.DBusNames;
import gio.DBusConnection;
import gio.DBusNodeInfo;
import gio.DBusProxy;
import gio.Task;
import glib.Variant;
import glib.VariantType;
import gobject.ObjectG;
import std.conv;
import std.datetime : SysTime;
import std.exception;

auto immutable dbusIntrospectionXML = import("dev.Cogitri.apkPolkit.interface");

/**
* DBus client class that deals with calling DBus method once the required dbus
* server is available.
*/
class DBusClient
{
    private static DBusClient m_instance;

    protected this()
    {
        auto dbusIntrospectionData = new DBusNodeInfo(dbusIntrospectionXML);
        this.proxy = new DBusProxy(BusType.SYSTEM, DBusProxyFlags.NONE, dbusIntrospectionData.interfaces[0],
                apkd_common.globals.dbusBusName, apkd_common.globals.dbusObjectPath,
                apkd_common.globals.dbusInterfaceName, null);
    }

    static DBusClient get()
    {
        if (m_instance is null)
        {
            m_instance = new DBusClient;
        }
        return m_instance;
    }

    void queryAsync(string[] packageNames, ApkDataBaseOperations dbOp,
            Cancellable cancellable, GAsyncReadyCallback callback, void* userData)
    {
        this.queryAsyncTask = new Task(null, cancellable, callback, userData);
        this.queryAsync(packageNames, dbOp, cancellable);
    }

    void queryAsync(string[] packageNames, ApkDataBaseOperations dbOp,
            Cancellable cancellable, Task task)
    {
        this.queryAsyncTask = task;
        this.queryAsync(packageNames, dbOp, cancellable);
    }

    void queryAsync(string[] packageNames, ApkDataBaseOperations dbOp, Cancellable cancellable)
    {
        Variant params;
        final switch (dbOp.val) with (ApkDataBaseOperations.Enum)
        {
        case listAvailablePackages:
        case listUpgradablePackages:
        case upgradeAllPackages:
        case updateRepositories:
        case listInstalledPackages:
            params = null;
            break;
        case addPackage:
        case upgradePackage:
            params = new Variant([new Variant(packageNames)]);
            break;
        case deletePackage:
            params = new Variant([new Variant(packageNames)]);
            break;
        case getAllowUntrustedRepos:
        case getAllProperties:
        case setAllowUntrustedRepos:
            assert(0);
        }

        this.proxy.call(dbOp.toString(), params, DBusCallFlags.NONE, G_MAXINT32,
                cancellable, &queryAsyncDbusCallFinish, &this.queryAsyncTask);
    }

    static Variant* queryFinish(GAsyncResult* res)
    in
    {
        assert(res);
    }
    out (result)
    {
        assert(result);
    }
    do
    {
        auto task = new Task(cast(GTask*) res);
        return cast(Variant*) task.propagatePointer();
    }

    Variant querySync(string[] packageNames, ApkDataBaseOperations dbOp, Cancellable cancellable)
    {
        Variant params;
        final switch (dbOp.val) with (ApkDataBaseOperations.Enum)
        {
        case listAvailablePackages:
        case listUpgradablePackages:
        case upgradeAllPackages:
        case updateRepositories:
        case listInstalledPackages:
            params = null;
            break;
        case addPackage:
        case upgradePackage:
            params = new Variant([new Variant(packageNames)]);
            break;
        case deletePackage:
            params = new Variant([new Variant(packageNames)]);
            break;
        case getAllowUntrustedRepos:
        case getAllProperties:
        case setAllowUntrustedRepos:
            assert(0);
        }
        return this.proxy.callSync(dbOp.toString(), params, DBusCallFlags.NONE,
                G_MAXINT32, cancellable);
    }

    Variant getProperty(ApkDataBaseOperations op, Cancellable cancellable)
    {
        auto params = new Variant([
                new Variant(apkd_common.globals.dbusInterfaceName),
                new Variant(op.toString()),
                ]);
        return this.proxy.callSync("org.freedesktop.DBus.Properties.Get",
                params, DBusCallFlags.NONE, G_MAXINT32, cancellable);
    }

    void setProperty(Variant param, Cancellable cancellable)
    {
        auto params = new Variant([
                new Variant(apkd_common.globals.dbusInterfaceName),
                new Variant("allowUntrustedRepos"), new Variant(param),
                ]);
        this.proxy.callSync("org.freedesktop.DBus.Properties.Set", params,
                DBusCallFlags.NONE, G_MAXINT32, cancellable);
    }

private:
    extern (C) static void queryAsyncDbusCallFinish(GObject* rawProxy,
            GAsyncResult* res, void* rawUserData)
    {
        auto proxy = new DBusProxy(cast(GDBusProxy*) rawProxy);
        auto dbusTask = new Task(cast(GTask*) res);
        auto value = proxy.callFinish(dbusTask);
        auto userTask = cast(Task*) rawUserData;

        userTask.returnPointer(&value, null);
    }

    Task queryAsyncTask;
    DBusProxy proxy;
    uint watcherId;
}
