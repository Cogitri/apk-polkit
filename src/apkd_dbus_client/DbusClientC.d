module apkd_dbus_client.DbusClientC;

import core.runtime;
import apkd_common.ApkDatabaseOperations;
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

enum ApkErrorEnum
{
    FAILED,
    DBUS_SPAWN_FAILED,
    APK_OP_FAILED,
    APK_QUERY_ASYNC_FAILED,
    APK_QUERY_ASYNC_FINISH_FAILED,
}

extern (C) GQuark apkd_error_quark() nothrow
{
    return assumeWontThrow(g_quark_from_static_string("apkd-error-quark"));
}

extern (C) bool apkd_init()
{
    return cast(bool) rt_init();
}

extern (C) bool apkd_deinit()
{
    return cast(bool) rt_term();
}

extern (C) void apkd_dbus_client_query_async(GPtrArray* rawPkgNamesPtrArray,
        uint len, ApkDataBaseOperations.Enum rawDbOp,
        bool allowUntrustedRepos, GCancellable* cancellable,
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
        auto error = assumeWontThrow(new ErrorG(apkd_error_quark(), ApkErrorEnum.DBUS_SPAWN_FAILED,
                assumeWontThrow(format("Spawning the DBusClient failed due to error %s!", e))));
        assumeWontThrow(task.returnError(error));
        return;
    }

    auto dbOp = ApkDataBaseOperations(rawDbOp);

    try
    {
        dbusClient.queryAsync(pkgNames, dbOp, allowUntrustedRepos,
                new Cancellable(cancellable), task);
    }
    catch (Exception e)
    {
        auto error = assumeWontThrow(new ErrorG(apkd_error_quark(), ApkErrorEnum.APK_QUERY_ASYNC_FAILED,
                assumeWontThrow(format("Executing the transaction %s failed due to error %s",
                dbOp, e))));
        assumeWontThrow(task.returnError(error));
    }
}

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
        assumeWontThrow(g_set_error(error, apkd_error_quark(), ApkErrorEnum.APK_QUERY_ASYNC_FINISH_FAILED,
                format("Failed to finish query que to error %s", e).toStringz()));
        return null;
    }
}

extern (C) GVariant* apkd_dbus_client_query_sync(GPtrArray* rawPkgNamesPtrArray, uint len,
        ApkDataBaseOperations.Enum rawDbOp, bool allowUntrustedRepos,
        GCancellable* cancellable, GError** error) nothrow
in
{
    assert(!(rawPkgNamesPtrArray is null && len != 0),
            "Tried to pass in a non-null GPtrArray with a len > 0!");
    assert(error is null || *error is null, "Musn't reuse an error!");
}
out (result)
{
    assert((result is null) ^ (*error is null),
            "If result is null error musn't be null (and the other way around)!");
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
        assumeWontThrow(g_set_error(error, apkd_error_quark(), ApkErrorEnum.DBUS_SPAWN_FAILED,
                assumeWontThrow(format("Spawning the DBusClient failed due to error %s!", e)).toStringz()));
        return null;
    }

    auto dbOp = ApkDataBaseOperations(rawDbOp);

    Variant variant;
    try
    {
        variant = dbusClient.querySync(pkgNames, dbOp, allowUntrustedRepos,
                new Cancellable(cancellable));
    }
    catch (Exception e)
    {
        assumeWontThrow(g_set_error(error, apkd_error_quark(), ApkErrorEnum.APK_OP_FAILED,
                assumeWontThrow(format("Executing the transaction %s failed due to error %s",
                dbOp, e)).toStringz()));
    }
    return assumeWontThrow(variant.getVariantStruct());
}
