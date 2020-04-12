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

module apkd_dbus_client.DbusClient;

import apkd_common.ApkDataBaseOperations;
import apkd_common.DBusPropertyOperations;
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
import gobject.Signals;
import std.conv;
import std.datetime : SysTime;
import std.exception;

/**
* The XML describing our DBus interface
*/
auto immutable dbusIntrospectionXML = import("dev.Cogitri.apkPolkit.interface");

/**
* DBus client class that deals with calling DBus method once the required dbus
* server is available.
*/
class DBusClient
{
    private static DBusClient m_instance;

    /**
    * Create a new DBusClient. Since this is a singleton only one should exist at a time. Note that
    * this isn't thread-safe.
    */
    protected this()
    {
        auto dbusIntrospectionData = new DBusNodeInfo(dbusIntrospectionXML);
        this.proxy = new DBusProxy(BusType.SYSTEM, DBusProxyFlags.NONE, dbusIntrospectionData.interfaces[0],
                apkd_common.globals.dbusBusName, apkd_common.globals.dbusObjectPath,
                apkd_common.globals.dbusInterfaceName, null);
    }

    /**
    * Get an existing instance of DBusClient if it exists already or create a new one.
    */
    static DBusClient get()
    {
        if (m_instance is null)
        {
            m_instance = new DBusClient;
        }
        return m_instance;
    }

    /**
    * Query a method in an async manner. The callback passed to this will be called
    * once the result is ready.
    *
    * Params:
    *   pkgnames    = The package names to run this operation on. Can be null if the operation
    *                 doesn't need it (e.g. for updateRepositories which doesn't take pkgnames).
    *   dbOp        = The operation to run on the database.
    *   cancellable = A Cancellable to cancel the operation if so desired.
    *   callback    = The callback to run once the operation is ready.
    *   userData    = Data to pass to the callback.
    *
    * Throws:
    * Throws a GException if something goes wrong in querying the method, or if the cancellable
    * was cancelled.
    */
    void queryAsync(string[] pkgnames, ApkDataBaseOperations dbOp,
            Cancellable cancellable, GAsyncReadyCallback callback, void* userData)
    {
        this.queryAsyncTask = new Task(null, cancellable, callback, userData);
        this.queryAsync(pkgnames, dbOp, cancellable);
    }

    /**
    * Query a method in an async manner. You probably want to pass a callback and userData instead
    * of constructing the task yourself.
    *
    * Params:
    *   pkgnames    = The package names to run this operation on. Can be null if the operation
    *                 doesn't need it (e.g. for updateRepositories which doesn't take pkgnames).
    *   dbOp        = The operation to run on the database.
    *   cancellable = A Cancellable to cancel the operation if so desired.
    *   task        = Task to run when the operation is ready.
    *
    * Throws:
    * Throws a GException if something goes wrong in querying the method, or if the cancellable
    * was cancelled.
    */
    void queryAsync(string[] pkgnames, ApkDataBaseOperations dbOp,
            Cancellable cancellable, Task task)
    {
        this.queryAsyncTask = task;
        this.queryAsync(pkgnames, dbOp, cancellable);
    }

    /**
    * Query a method in an async manner. Calls the callback previously set. If you haven't
    * set a callback yet use the overload where you can pass a callback in.
    *
    * Params:
    *   pkgnames    = The package names to run this operation on. Can be null if the operation
    *                 doesn't need it (e.g. for updateRepositories which doesn't take pkgnames).
    *   dbOp        = The operation to run on the database.
    *   cancellable = A Cancellable to cancel the operation if so desired.
    *
    * Throws:
    * Throws a GException if something goes wrong in querying the method, or if the cancellable
    * was cancelled.
    */
    void queryAsync(string[] pkgnames, ApkDataBaseOperations dbOp, Cancellable cancellable)
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
            params = new Variant([new Variant(pkgnames)]);
            break;
        case deletePackage:
            params = new Variant([new Variant(pkgnames)]);
            break;
        case searchForPackages:
            params = new Variant([new Variant(pkgnames)]);
            break;
        }

        this.proxy.call(dbOp.toString(), params, DBusCallFlags.NONE, G_MAXINT32,
                cancellable, &queryAsyncDbusCallFinish, &this.queryAsyncTask);
    }

    /**
    * Get the result of an async query. You'd typically call this in your callback
    * to get the actual result.
    *
    * Params:
    *   res = The GAsyncResult you got in your callback. Mustn't be null.
    */
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

    /**
    * Query a method in a synchronous manner. You probably want to use queryAsync instead.
    *
    * Params:
    *   pkgnames    = The package names to run this operation on. Can be null if the operation
    *                 doesn't need it (e.g. for updateRepositories which doesn't take pkgnames).
    *   dbOp        = The operation to run on the database.
    *   cancellable = A Cancellable to cancel the operation if so desired.
    *
    * Throws:
    * Throws a GException if something goes wrong in querying the method, or if the cancellable
    * was cancelled.
    */
    Variant querySync(string[] pkgnames, ApkDataBaseOperations dbOp, Cancellable cancellable)
    out (result)
    {
        assert(result);
    }
    do
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
            params = new Variant([new Variant(pkgnames)]);
            break;
        case deletePackage:
            params = new Variant([new Variant(pkgnames)]);
            break;
        case searchForPackages:
            params = new Variant([new Variant(pkgnames)]);
            break;
        }

        return this.proxy.callSync(dbOp.toString(), params, DBusCallFlags.NONE,
                G_MAXINT32, cancellable);
    }

    /**
    * Get the value of a property in a synchronous manner.
    *
    * Params:
    *   operation   = The DBusPropertyOperation to run. The direction of the operation must be get.
    *   cancellable = A Cancellable to cancel the operation if so desired.
    *
    * Throws:
    * Throws a GException if something goes wrong in querying the method, or if the cancellable
    * was cancelled.
    */
    Variant getProperty(DBusPropertyOperations operation, Cancellable cancellable)
    in
    {
        assert(operation.direction == DBusPropertyOperations.DirectionEnum.get);
    }
    out (result)
    {
        assert(result);
    }
    do
    {
        auto params = new Variant([
                new Variant(apkd_common.globals.dbusInterfaceName),
                new Variant(operation.toString()),
                ]);
        return this.proxy.callSync("org.freedesktop.DBus.Properties.Get",
                params, DBusCallFlags.NONE, G_MAXINT32, cancellable);
    }

    /**
    * Set the value of a property in a synchronous manner.
    *
    * Params:
    *   operation   = The DBusPropertyOperation to run. The direction of the operation must be set.
    *   param       = The value to set the property to
    *   cancellable = A Cancellable to cancel the operation if so desired.
    *
    * Throws:
    * Throws a GException if something goes wrong in querying the method, or if the cancellable
    * was cancelled.
    */
    void setProperty(DBusPropertyOperations operation, Variant param, Cancellable cancellable)
    in
    {
        assert(operation.direction == DBusPropertyOperations.DirectionEnum.set);
    }
    do
    {
        auto params = new Variant([
                new Variant(apkd_common.globals.dbusInterfaceName),
                new Variant(operation.toString()), new Variant(param),
                ]);
        this.proxy.callSync("org.freedesktop.DBus.Properties.Set", params,
                DBusCallFlags.NONE, G_MAXINT32, cancellable);
    }

    /**
    * Connect DBus signals. Returns the source ID of the connection.
    *
    * Params:
    *   cb       = Callback to call when the signal is received
    *   userData = userData to pass to the callback
    */
    ulong connectSignals(GCallback cb, void* userData)
    {
        return Signals.connect(this.proxy, "g-signal", cb, userData);
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
