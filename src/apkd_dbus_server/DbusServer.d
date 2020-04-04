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

module apkd_dbus_server.DBusServer;

import apkd.ApkDataBase;
import apkd.ApkPackage;
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
import glib.c.functions : g_quark_from_static_string, g_variant_new;
import glib.GException;
import glib.Variant;
import glib.VariantBuilder;
import glib.VariantType;
import std.conv : to, ConvException;
import std.concurrency : receive;
import std.exception;
import std.experimental.logger;
import std.format : format;
import std.string : toStringz;

enum ApkdDbusServerErrorQuarkEnum
{
    Failed,
    AddError,
    DeleteError,
    ListAvailableError,
    ListInstalledError,
    ListUpgradableError,
    UpdateRepositoriesError,
    UpgradePackageError,
    UpgradeAllPackagesError,
}

extern (C) GQuark ApkdDbusServerErrorQuark() nothrow
{
    return assumeWontThrow(g_quark_from_static_string("apkd-dbus-server-error-quark"));
}

/// The DBus interface this dbus application exposes as XML
auto immutable dbusIntrospectionXML = import("dev.Cogitri.apkPolkit.interface");

/// DBusServer class, that is used to setup the dbus connection and handle method calls
class DBusServer
{
    /**
    * While construction apkd-dbus-server's DBus name is acquired and handler methods are set,
    * which are invoked by GDBus upon receiving a method call/losing the name etc.
    */
    this()
    {
        tracef("Trying to acquire DBus name %s", apkd_common.globals.dbusBusName);
        auto dbusFlags = BusNameOwnerFlags.NONE;
        this.ownerId = DBusNames.ownName(BusType.SYSTEM, apkd_common.globals.dbusBusName,
                dbusFlags, &onBusAcquired, &onNameAcquired, &onNameLost, null, null);
    }

    ~this()
    {
        DBusNames.unownName(this.ownerId);
    }

    /**
    * Passed to GDBus to handle incoming method calls. In this function we match the method name to the function to be
    * executed, authorize the user via polkit and send the return value back. We try very hard not to throw here and
    * instead send a dbus error mesage back and return early, since throwing here would mean crashing the entire server.
    */
    extern (C) static void methodHandler(GDBusConnection* DBusConnection, const char* sender, const char*, const char*,
            const char* methodName, GVariant* parameters,
            GDBusMethodInvocation* invocation, void*)
    {
        tracef("Handling method %s from sender %s", methodName.to!string, sender.to!string);
        auto dbusInvocation = new DBusMethodInvocation(invocation);

        ApkDataBaseOperations databaseOperations;
        try
        {
            databaseOperations = ApkDataBaseOperations(methodName.to!string);
        }
        catch (ConvException e)
        {
            errorf("Unkown method name %s!", methodName.to!string);
            return;
        }

        auto authorized = false;

        info("Tying to authorized user...");
        try
        {
            authorized = queryPolkitAuth(databaseOperations.toPolkitAction(), sender.to!string);
        }
        catch (GException e)
        {
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.AUTH_FAILED,
                    format("Authorization for operation %s for has failed due to error '%s'!",
                        databaseOperations, e));
            return;
        }

        if (authorized)
        {
            info("Authorization succeeded!");
            Variant[] ret;
            final switch (databaseOperations.val) with (ApkDataBaseOperations.Enum)
            {
            case addPackage:
                auto variant = new Variant(parameters);
                const auto allowUntrustedRepos = variant.getChildValue(0).getBoolean();
                auto pkgnames = variant.getChildValue(1).getStrv();
                try
                {
                    ret ~= new Variant(ApkInterfacer.addPackage(pkgnames));
                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.AddError,
                            format("Couldn't add package%s %s due to error %s",
                                pkgnames.length == 0 ? "" : "s", pkgnames, e));
                    return;
                }
                break;
            case deletePackage:
                auto variant = new Variant(parameters);
                auto pkgnames = variant.getChildValue(0).getStrv();
                try
                {
                    ret ~= new Variant(ApkInterfacer.deletePackage(pkgnames));
                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.DeleteError,
                            format("Couldn't delete package%s %s due to error %s",
                                pkgnames.length == 0 ? "" : "s", pkgnames, e));
                    return;
                }
                break;
            case listAvailablePackages:
                auto variant = new Variant(parameters);
                const auto allowUntrustedRepos = variant.getChildValue(0).getBoolean();
                try
                {
                    ret ~= apkPackageArrayToVariant(ApkInterfacer.getAvailablePackages());
                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.ListAvailableError,
                            format("Couldn't list available packages due to error %s", e));
                    return;
                }
                break;
            case listInstalledPackages:
                try
                {
                    ret ~= apkPackageArrayToVariant(ApkInterfacer.getInstalledPackages());
                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.ListInstalledError,
                            format("Couldn't list installed packages due to error %s", e));
                    return;
                }
                break;
            case listUpgradablePackages:
                auto variant = new Variant(parameters);
                const auto allowUntrustedRepos = variant.getChildValue(0).getBoolean();
                try
                {
                    ret ~= apkPackageArrayToVariant(ApkInterfacer.getUpgradablePackages());

                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.ListUpgradableError,
                            format("Couldn't list upgradable packages due to error %s", e));
                    return;
                }
                break;
            case updateRepositories:
                auto variant = new Variant(parameters);
                const auto allowUntrustedRepos = variant.getChildValue(0).getBoolean();
                try
                {
                    ret ~= new Variant(ApkInterfacer.updateRepositories());
                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.UpdateRepositoriesError,
                            format("Couldn't update repositories due to error %s", e));
                    return;
                }
                break;
            case upgradeAllPackages:
                try
                {
                    ret ~= new Variant(ApkInterfacer.upgradeAllPackages());

                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.UpgradeAllPackagesError,
                            format("Couldn't upgrade all packages due to error %s", e));
                    return;
                }
                break;
            case upgradePackage:
                auto variant = new Variant(parameters);
                const auto allowUntrustedRepos = variant.getChildValue(0).getBoolean();
                auto pkgnames = variant.getChildValue(1).getStrv();
                try
                {
                    ret ~= new Variant(ApkInterfacer.upgradePackage(pkgnames));
                }
                catch (Exception e)
                {
                    dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                            ApkdDbusServerErrorQuarkEnum.DeleteError,
                            format("Couldn't upgrade package%s %s due to error %s",
                                pkgnames.length == 0 ? "" : "s", pkgnames, e));
                    return;
                }
                break;
            }

            auto retVariant = new Variant(ret);
            dbusInvocation.returnValue(retVariant);
        }
        else
        {
            error("Autorization failed!");
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.ACCESS_DENIED,
                    format("Authorization for operation %s for has failed for user!",
                        databaseOperations));
        }
    }

    /**
    * Passed to GDBus to be executed once we've successfully established a connection to the
    * DBus bus. We register our methods here.
    */
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

    /**
    * Passed to GDBus to be executed once we've acquired the DBus name (no one else owns
    * it already, we have the necessary permissions, etc.).
    */
    extern (C) static void onNameAcquired(GDBusConnection* dbusConnection, const char* name, void*)
    {
        tracef("Acquired the DBus name '%s'", name.to!string);
    }

    /**
    * Passed to GDBus to be executed if we lose our DBus name (e.g. if someone else owns it already,
    * we don't have the necessary permissions, etc.).
    */
    extern (C) static void onNameLost(GDBusConnection* DBusConnection, const char* name, void*)
    {
        fatalf("Lost DBus connection %s!", name.to!string);
    }

private:

    /// Helper method to convert a ApkPackage array to a Variant for sending it over DBus
    static Variant apkPackageArrayToVariant(ApkPackage[] pkgArr)
    {
        auto arrBuilder = new VariantBuilder(new VariantType("a(ssssssssssstt)"));

        foreach (pkg; pkgArr)
        {
            auto pkgBuilder = new VariantBuilder(new VariantType("(ssssssssssstt)"));
            static foreach (member; [
                    "name", "newVersion", "oldVersion", "arch", "license",
                    "origin", "maintainer", "url", "description", "commit",
                    "filename"
                ])
            {
                pkgBuilder.addValue(new Variant(__traits(getMember, pkg,
                        member) ? __traits(getMember, pkg, member) : ""));
            }
            static foreach (member; ["installedSize", "size"])
            {
                pkgBuilder.addValue(new Variant(__traits(getMember, pkg, member)));
            }
            arrBuilder.addValue(pkgBuilder.end());
        }

        return arrBuilder.end();
    }

    uint ownerId;
}

/**
* Helper class that is used in DBusServer.handleMethod to call the right functions on
* apkd.ApkDatabase, handle logging etc.
*/
class ApkInterfacer
{
    static bool updateRepositories()
    {
        trace("Trying to update repositories");
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        return dbGuard.db.updateRepositories(false);
    }

    static bool upgradePackage(string[] pkgname)
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

    static bool deletePackage(string[] pkgname)
    {
        tracef("Trying to delete package %s", pkgname);
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.deletePackage(pkgname);
            infof("Successfully deleted pakage '%s'", pkgname);
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

    static bool addPackage(string[] pkgname)
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

    static ApkPackage[] getAvailablePackages()
    {
        trace("Trying to list all available packages");
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            return dbGuard.db.getAvailablePackages();
        }
        catch (ApkException e)
        {
            criticalf("Failed to list all available packages due to APK error '%s'", e);
            return [];
        }
    }

    static ApkPackage[] getInstalledPackages()
    {
        trace("Trying to list all installed packages");
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            return dbGuard.db.getInstalledPackages();
        }
        catch (ApkException e)
        {
            criticalf("Failed to list all installed packages due to APK error '%s'", e);
            return [];
        }
    }

    static ApkPackage[] getUpgradablePackages()
    {
        trace("Trying to list upgradable packages");
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            return dbGuard.db.getUpgradablePackages();
        }
        catch (ApkException e)
        {
            criticalf("Failed to list upgradable packages due to APK error '%s'", e);
            return [];
        }
    }
}

/**
* Helper struct that is used to destroy the apkd.ApkDatabase class as soon as
* it goes out of scope to ensure we don't lock the db for longer than we have to.
*/
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
