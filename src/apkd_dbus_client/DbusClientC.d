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

module apkd_dbus_client.DbusClientC;

import core.runtime;
import apkd_common.ApkDataBaseOperations;
import apkd_dbus_client.DbusClient;
import gio.c.types : GAsyncReadyCallback, GAsyncResult, GCancellable, GError;
import gio.Cancellable;
import gio.Task;
import glib.c.functions : g_quark_from_static_string, g_set_error;
import glib.c.types : GPtrArray, GVariant, GQuark;
import glib.ErrorG;
import glib.PtrArray;
import glib.Variant;
import gobject.c.types : GCallback;
import std.conv : to;
import std.exception : assumeWontThrow;
import std.format : format;
import std.string;

/**
* Different errors that might occur during operations.
*/
enum ApkDbusClientErrorEnum
{
    FAILED,
    DBUS_SPAWN_FAILED,
    APK_OP_FAILED,
    APK_QUERY_ASYNC_FAILED,
    APK_QUERY_ASYNC_FINISH_FAILED,
    DBUS_SIGNAL_CONNECT_FAILED,
}

/**
* GQuark for our error domain
*/
extern (C) GQuark apkd_dbus_client_error_quark() nothrow
{
    return assumeWontThrow(g_quark_from_static_string("apkd-dbus-client-error-quark"));
}

/**
* Initialize the library. This must be called before any other functions
* of this library.
*/
extern (C) bool apkd_init()
{
    return cast(bool) rt_init();
}

/**
* Deinitialize the library. No other function of this library may be called
* after this.
*/
extern (C) bool apkd_deinit()
{
    return cast(bool) rt_term();
}

/**
* Query a method in an async manner. The callback passed to this will be called
* once the result is ready.
*
* Params:
*   rawPkgNamesPtrArray = The package names to run this operation on. Can be null if the operation
*                         doesn't need it (e.g. for updateRepositories which doesn't take pkgnames).
*   rawDbOp             = The operation to run on the database.
*   cancellable         = A Cancellable to cancel the operation if so desired.
*   callback            = The callback to run once the operation is ready.
*   userData            = Data to pass to the callback.
*   error               = A location to save errors to. May be null to ignore erors.
*/
extern (C) void apkd_dbus_client_query_async(GPtrArray* rawPkgNamesPtrArray,
        ApkDataBaseOperations.Enum rawDbOp, GCancellable* cancellable,
        GAsyncReadyCallback callback, void* userData) nothrow
{
    string[] pkgNames;

    if (rawPkgNamesPtrArray)
    {
        auto pkgNamesPtrArray = assumeWontThrow(new PtrArray(rawPkgNamesPtrArray));

        foreach (i; 0 .. assumeWontThrow(pkgNamesPtrArray.len()))
        {
            auto pkgname = cast(char*) assumeWontThrow(pkgNamesPtrArray.index(i));
            pkgNames ~= pkgname.to!string;
        }
    }

    auto task = assumeWontThrow(new Task(null,
            assumeWontThrow(new Cancellable(cancellable)), callback, userData));

    DBusClient dbusClient;
    try
    {
        dbusClient = DBusClient.get();
    }
    catch (Exception e)
    {
        auto error = assumeWontThrow(new ErrorG(apkd_dbus_client_error_quark(),
                ApkDbusClientErrorEnum.DBUS_SPAWN_FAILED,
                assumeWontThrow(format("Spawning the DBusClient failed due to error %s!", e))));
        assumeWontThrow(task.returnError(error));
        return;
    }

    auto dbOp = new ApkDataBaseOperations(rawDbOp);

    try
    {
        dbusClient.queryAsync(pkgNames, dbOp, new Cancellable(cancellable), task);
    }
    catch (Exception e)
    {
        auto error = assumeWontThrow(new ErrorG(apkd_dbus_client_error_quark(),
                ApkDbusClientErrorEnum.APK_QUERY_ASYNC_FAILED,
                assumeWontThrow(format("Executing the transaction %s failed due to error %s",
                dbOp, e))));
        assumeWontThrow(task.returnError(error));
    }
}

/**
* Get the result of an async query. You'd typically call this in your callback
* to get the actual result.
*
* Params:
*   res   = The GAsyncResult you got in your callback. Mustn't be null.
*   error = A location to save errors to. May be null to ignore erors.
*/
extern (C) GVariant* apkd_dbus_client_query_finish(GAsyncResult* res, GError** error) nothrow
in
{
    assert(res);
    assert(error is null || *error is null);
}
out (result)
{
    assert(result);
}
do
{
    try
    {
        return DBusClient.queryFinish(res).getVariantStruct();
    }
    catch (Exception e)
    {
        assumeWontThrow(g_set_error(error, apkd_dbus_client_error_quark(),
                ApkDbusClientErrorEnum.APK_QUERY_ASYNC_FINISH_FAILED,
                format("Failed to finish query que to error %s", e).toStringz()));
        return null;
    }
}

/**
* Query a method in a synchronous manner. You probably want to use apkd_dbus_client_query_async instead.
*
* Params:
*   rawPkgNamesPtrArray = The package names to run this operation on. Can be null if the operation
*                         doesn't need it (e.g. for updateRepositories which doesn't take pkgnames).
*   rawDbOp             = The operation to run on the database.
*   cancellable         = A Cancellable to cancel the operation if so desired.
*   error               = A location to save errors to. May be null to ignore erors.
*/
extern (C) GVariant* apkd_dbus_client_query_sync(GPtrArray* rawPkgNamesPtrArray,
        ApkDataBaseOperations.Enum rawDbOp, GCancellable* cancellable, GError** error) nothrow
in
{
    assert(error is null || *error is null, "Musn't reuse an error!");
}
out (result)
{
    assert(!((result is null && *error is null) || (result && *error)),
            "result and error can't both be null or set at the same time!");
}
do
{
    string[] pkgNames;

    if (rawPkgNamesPtrArray)
    {
        auto pkgNamesPtrArray = assumeWontThrow(new PtrArray(rawPkgNamesPtrArray));

        foreach (i; 0 .. assumeWontThrow(pkgNamesPtrArray.len()))
        {
            auto pkgname = cast(char*) assumeWontThrow(pkgNamesPtrArray.index(i));
            pkgNames ~= pkgname.to!string;
        }
    }

    DBusClient dbusClient;
    try
    {
        dbusClient = DBusClient.get();
    }
    catch (Exception e)
    {
        assumeWontThrow(g_set_error(error, apkd_dbus_client_error_quark(), ApkDbusClientErrorEnum.DBUS_SPAWN_FAILED,
                assumeWontThrow(format("Spawning the DBusClient failed due to error %s!", e)).toStringz()));
        return null;
    }

    auto dbOp = new ApkDataBaseOperations(rawDbOp);

    Variant variant;
    try
    {
        variant = dbusClient.querySync(pkgNames, dbOp, new Cancellable(cancellable));
    }
    catch (Exception e)
    {
        assumeWontThrow(g_set_error(error, apkd_dbus_client_error_quark(), ApkDbusClientErrorEnum.APK_OP_FAILED,
                assumeWontThrow(format("Executing the transaction %s failed due to error %s",
                dbOp, e)).toStringz()));
        return null;
    }
    return assumeWontThrow(variant.getVariantStruct());
}

/**
* Connect DBus signals. Returns the source ID of the connection.
*
* Params:
*   cb       = Callback to call when the signal is received
*   userData = userData to pass to the callback
*   error    = A location to save errors to. May be null to ignore erors.
*/
extern (C) ulong apkd_dbus_client_connect_signals(GCallback cb, void* userData, GError** error)
in
{
    assert(error is null || *error is null, "Musn't reuse an error!");
}
do
{
    DBusClient dbusClient;
    try
    {
        dbusClient = DBusClient.get();
    }
    catch (Exception e)
    {
        assumeWontThrow(g_set_error(error, apkd_dbus_client_error_quark(), ApkDbusClientErrorEnum.DBUS_SPAWN_FAILED,
                assumeWontThrow(format("Spawning the DBusClient failed due to error %s!", e)).toStringz()));
        return 0;
    }

    try
    {
        return dbusClient.connectSignals(cb, userData);
    }
    catch (Exception e)
    {
        assumeWontThrow(g_set_error(error, apkd_dbus_client_error_quark(),
                ApkDbusClientErrorEnum.DBUS_SIGNAL_CONNECT_FAILED,
                assumeWontThrow(format("Connecting the signals failed due to error %s!", e)).toStringz()));
        return 0;
    }
}
