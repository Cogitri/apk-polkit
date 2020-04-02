module apkd_dbus_client.DbusClientC;

import core.runtime;
import apkd_common.ApkDatabaseOperations;
import apkd_dbus_client.DbusClient;
import gio.c.types : GAsyncReadyCallback, GAsyncResult, GCancellable, GError;
import gio.Cancellable;
import glib.c.types : GPtrArray, GVariant;
import gobject.c.types : GCallback;
import std.conv;

extern (C) bool apkd_init()
{
    return cast(bool) rt_init();
}

extern (C) bool apkd_deinit()
{
    return cast(bool) rt_term();
}

extern (C) void apkd_dbus_client_query_async(GPtrArray* rawPkgNames, uint len, ApkDataBaseOperations.Enum rawDbOp,
        bool allowUntrustedRepos, GCancellable* cancellable,
        GAsyncReadyCallback callback, void* userData)
{
    string[] pkgNames;

    for (uint i = 0; i < len; i++)
    {
        pkgNames[i] = rawPkgNames[i].to!string;
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
    return DBusClient.queryFinish(res).getVariantStruct();
}
