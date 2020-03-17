module apkd_dbus_server.DBusServer;

import apkd.ApkDataBase;
import apkd.exceptions;
import apkd_common.ApkDatabaseOperations;
static import apkd_common.globals;
import apkd_dbus_server.Polkit;
import gio.Cancellable;
import gio.DBusConnection;
import gio.DBusNames;
static import gio.DBusError;
import gio.DBusNodeInfo;
import gio.DBusMethodInvocation;
import gio.c.types : BusNameOwnerFlags, BusType, GDBusInterfaceVTable,
    GDBusMethodInvocation, GVariant;
import glib.GException;
import glib.Variant;
import std.conv : to, ConvException;
import std.concurrency : receive;
import std.exception;
import std.experimental.logger;
import std.format : format;

auto immutable dbusIntrospectionXML = import("dev.Cogitri.apkPolkit.interface");

class DBusServer
{
    this()
    {
        auto dbusFlags = BusNameOwnerFlags.NONE;
        this.ownerId = DBusNames.ownName(BusType.SYSTEM, apkd_common.globals.dbusBusName,
                dbusFlags, &onBusAcquired, &onNameAcquired, &onNameLost, null, null);
    }

    ~this()
    {
        DBusNames.unownName(this.ownerId);
    }

    extern (C) static void methodHandler(GDBusConnection* DBusConnection, const char* sender, const char*, const char*,
            const char* methodName, GVariant* parameters,
            GDBusMethodInvocation* invocation, void*)
    {
        tracef("Handling method %s from sender %s", methodName.to!string, sender.to!string);

        ApkDataBaseOperations databaseOperations;
        try
        {
            databaseOperations = new ApkDataBaseOperations(methodName.to!string);
        }
        catch (ConvException e)
        {
            errorf("Unkown method name %s!", methodName.to!string);
            return;
        }

        auto authorized = false;

        try
        {
            authorized = queryPolkitAuth(databaseOperations.toPolkitAction(), sender.to!string);
        }
        catch (GException e)
        {
            auto dbusInvocation = new DBusMethodInvocation(invocation);
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.AUTH_FAILED,
                    format("Authorization for operation %s for has failed due to error '%s'!",
                        methodName.to!string, e));
        }

        if (authorized)
        {
            Variant[] ret;
            final switch (databaseOperations.val) with (ApkDataBaseOperations.Enum)
            {
            case addPackage:
                auto variant = new Variant(parameters);
                string pkgname = variant.getChildValue(0).getBytestring();
                ret ~= new Variant(ApkInterfacer.addPackage(pkgname));
                break;
            case deletePackage:
                auto variant = new Variant(parameters);
                string pkgname = variant.getChildValue(0).getBytestring();
                ret ~= new Variant(ApkInterfacer.deletePackage(pkgname));
                break;
            case listAvailablePackages:
            case listInstalledPackages:
                break;
            case updateRepositories:
                ret ~= new Variant(ApkInterfacer.updateRepositories());
                break;
            case upgradeAllPackages:
                ret ~= new Variant(ApkInterfacer.upgradeAllPackages());
                break;
            case upgradePackage:
                auto variant = new Variant(parameters);
                string pkgname = variant.getChildValue(0).getBytestring();
                ret ~= new Variant(ApkInterfacer.upgradePackage(pkgname));
                break;
            }

            auto dbusInvocation = new DBusMethodInvocation(invocation);
            auto retVariant = new Variant(ret);
            dbusInvocation.returnValue(retVariant);
        }
        else
        {
            auto dbusInvocation = new DBusMethodInvocation(invocation);
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.ACCESS_DENIED,
                    format("Authorization for operation %s for has failed for user!",
                        methodName.to!string));
        }
    }

    extern (C) static void onBusAcquired(GDBusConnection* gdbusConnection, const char*, void*)
    {
        trace("Acquired the DBus connection");
        auto interfaceVTable = GDBusInterfaceVTable(&methodHandler, null, null, null);
        auto dbusConnection = new DBusConnection(gdbusConnection);

        auto dbusIntrospectionData = new DBusNodeInfo(dbusIntrospectionXML);
        enforce(dbusIntrospectionData !is null);

        const auto regId = dbusConnection.registerObject(apkd_common.globals.dbusObjectPath,
                dbusIntrospectionData.interfaces[0], &interfaceVTable, null, null);

        enforce(regId > 0);
    }

    extern (C) static void onNameAcquired(GDBusConnection* dbusConnection, const char* name, void*)
    {
        tracef("Acquired the DBus name '%s'", name.to!string);
    }

    extern (C) static void onNameLost(GDBusConnection* DBusConnection, const char* name, void*)
    {
        fatalf("Lost DBus connection %s!", name.to!string);
    }

private:
    uint ownerId;
}

class ApkInterfacer
{
    static bool updateRepositories()
    {
        trace("Trying to update repositories");
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        return dbGuard.db.updateRepositories(false);
    }

    static bool upgradePackage(string pkgname)
    {
        tracef("Trying to upgrade package '%s'", pkgname);
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.upgradePackage(pkgname);
            return true;
        }
        catch (ApkException e)
        {
            criticalf("Failed to upgrade package '%s' due to APK error '%s'", pkgname, e);
            return false;
        }
        catch (UserErrorException e)
        {
            criticalf("Failed to upgrade package '%s' due to error '%s'", pkgname, e);
            return false;
        }
    }

    static bool upgradeAllPackages()
    {
        trace("Trying upgrade all packages");
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.upgradeAllPackages();
            return true;
        }
        catch (ApkException e)
        {
            criticalf("Failed to upgrade all packages due to APK error '%s'", e);
            return false;
        }
        catch (UserErrorException e)
        {
            criticalf("Failed to upgrade all packages due to error '%s'", e);
            return false;
        }
    }

    static bool deletePackage(string pkgname)
    {
        tracef("Trying to delete package %s", pkgname);
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.deletePackage(pkgname);
            info("Successfully deleted pakage '%s'", pkgname);
            return true;
        }
        catch (ApkException e)
        {
            criticalf("Failed to delete package '%s' due to APK error '%s'", pkgname, e);
            return false;
        }
        catch (UserErrorException e)
        {
            criticalf("Failed to delete package '%s' due to error '%s'", pkgname, e);
            return false;
        }
    }

    static bool addPackage(string pkgname)
    {
        tracef("Trying to add package: %s", pkgname);
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.addPackage(pkgname);
            return true;
        }
        catch (ApkException e)
        {
            criticalf("Failed to add package '%s' due to APK error '%s'", pkgname, e);
            return false;
        }
        catch (UserErrorException e)
        {
            criticalf("Failed to add package '%s' due to error '%s'", pkgname, e);
            return false;
        }
    }
}

struct DatabaseGuard
{
    @property ref ApkDataBase db()
    {
        return this.m_db;
    }

    ~this()
    {
        this.m_db.destroy;
    }

private:
    ApkDataBase m_db;
}
