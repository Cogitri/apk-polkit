module apkd_dbus_client.DbusClientC;

import core.runtime;
import apkd_common.ApkDatabaseOperations;
import apkd_dbus_client.DbusClient;
import gio.c.types : GAsyncReadyCallback, GAsyncResult, GCancellable, GError;
import gio.Cancellable;
import glib.c.types : GPtrArray, GVariant;
import glib.ErrorG;
import glib.PtrArray;
import gobject.c.types : GCallback;
import std.conv : to;
import std.format : format;

extern (C) bool apkd_init()
{
    return cast(bool) rt_init();
}

extern (C) bool apkd_deinit()
{
    return cast(bool) rt_term();
}

extern (C) void apkd_dbus_client_query_async(GPtrArray* rawPkgNamesPtrArray, uint len, ApkDataBaseOperations.Enum rawDbOp,
        bool allowUntrustedRepos, GCancellable* cancellable,
        GAsyncReadyCallback callback, void* userData)
{
    string[] pkgNames;

    if(rawPkgNamesPtrArray) {
        auto pkgNamesPtrArray = new PtrArray(rawPkgNamesPtrArray);

        foreach(i; 0..pkgNamesPtrArray.len()) {
            auto pkgname = cast(char*) pkgNamesPtrArray.index(i);
            pkgNames ~= pkgname.to!string;
        }
    }

    auto dbusClient = DBusClient.get();
    auto dbOp = ApkDataBaseOperations(rawDbOp);
    dbusClient.queryAsync(pkgNames, dbOp, allowUntrustedRepos,
            new Cancellable(cancellable), callback, &dbOp);
}

extern (C) GVariant* apkd_dbus_client_query_finish(GAsyncResult* res, GError** error)
in
{
    assert(res);
    assert(error && *error);
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
        auto errorG = new ErrorG(0, 0, format("Failed to execute query due to error %s", e));
        *error = errorG.getErrorGStruct();
        return null;
    }
}

extern (C) GVariant* apkd_dbus_client_query_sync(GPtrArray* rawPkgNamesPtrArray, uint len,
        ApkDataBaseOperations.Enum rawDbOp, bool allowUntrustedRepos, GCancellable* cancellable)
{
    string[] pkgNames;

    if(rawPkgNamesPtrArray) {
        auto pkgNamesPtrArray = new PtrArray(rawPkgNamesPtrArray);

        foreach(i; 0..pkgNamesPtrArray.len()) {
            auto pkgname = cast(char*) pkgNamesPtrArray.index(i);
            pkgNames ~= pkgname.to!string;
        }
    }

    auto dbusClient = DBusClient.get();
    auto dbOp = ApkDataBaseOperations(rawDbOp);
    auto variant = dbusClient.querySync(pkgNames, dbOp, allowUntrustedRepos,
            new Cancellable(cancellable));
    return variant.getVariantStruct();
}
