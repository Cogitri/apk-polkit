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
import apkd_common.CommonOperations;
import apkd_common.ApkDataBaseOperations;
import apkd_common.DBusPropertyOperations;
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
import glib.c.functions : g_quark_from_static_string, g_set_error,
    g_variant_new, g_variant_builder_add;
import glib.GException;
import glib.Variant;
import glib.VariantBuilder;
import glib.VariantType;
import std.conv : to, ConvException;
import std.concurrency : receive;
import std.exception;
import std.experimental.logger;
import std.format : format;
import std.string : capitalize;

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

struct ApkdDbusServerProperties
{
    enum Enum
    {
        allowUntrustedRepos,
    }

    this(Enum val)
    {
        this.m_val = val;
    }

    this(string name)
    {
        this.m_val = name.to!Enum;
    }

    string toString() const
    {
        return this.m_val.to!string;
    }

    string toPolkitAction() const
    {
        immutable auto prefix = "dev.Cogitri.apkPolkit.Helper";

        string action;

        final switch (this.m_val) with (Enum)
        {
        case allowUntrustedRepos:
            action = "setAllowUntrustedRepos";
            break;
        }

        return prefix ~ "." ~ action;
    }

    @property Enum val() const
    {
        return this.m_val;
    }

private:
    Enum m_val;
}

/// The DBus interface this dbus application exposes as XML
auto immutable dbusIntrospectionXML = import("dev.Cogitri.apkPolkit.interface");

struct UserData
{
    bool allowUntrustedRepositories;
    string root;
}

/// DBusServer class, that is used to setup the dbus connection and handle method calls
class DBusServer
{
    /**
    * While construction apkd-dbus-server's DBus name is acquired and handler methods are set,
    * which are invoked by GDBus upon receiving a method call/losing the name etc.
    * Parameters:
    *   root    = The root of the database. Useful to install to places other than /
    */
    this(in string root = null)
    {
        tracef("Trying to acquire DBus name %s.", apkd_common.globals.dbusBusName);
        this.userData = UserData(false, null);
        auto dbusFlags = BusNameOwnerFlags.NONE;
        this.ownerId = DBusNames.ownName(BusType.SYSTEM, apkd_common.globals.dbusBusName,
                dbusFlags, &onBusAcquired, &onNameAcquired, &onNameLost, &this.userData, null);
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
    extern (C) static void methodHandler(GDBusConnection* dbusConnection,
            const char* sender, const char* objectPath, const char* interfaceName,
            const char* methodName, GVariant* parameters,
            GDBusMethodInvocation* invocation, void* userDataPtr)
    {
        tracef("Handling method %s from sender %s", methodName.to!string, sender.to!string);
        auto dbusInvocation = new DBusMethodInvocation(invocation);
        auto variant = new Variant(parameters);
        auto userData = cast(UserData*) userDataPtr;

        CommonOperations operation;
        try
        {
            if (interfaceName.to!string == "org.freedesktop.DBus.Properties")
            {
                switch (methodName.to!string)
                {
                case "Get":
                    ulong len;
                    auto propertyName = variant.getChildValue(1).getString(len);
                    operation = new DBusPropertyOperations(propertyName.to!(DBusPropertyOperations.Enum),
                            DBusPropertyOperations.DirectionEnum.get);
                    break;
                case "Set":
                    ulong len;
                    auto propertyName = variant.getChildValue(1).getString(len);
                    operation = new DBusPropertyOperations(propertyName.to!(DBusPropertyOperations.Enum),
                            DBusPropertyOperations.DirectionEnum.set);
                    break;
                case "GetAll":
                    operation = new DBusPropertyOperations("getAll");
                    break;
                default:
                    assert(0);
                }
            }
            else
            {
                operation = new ApkDataBaseOperations(methodName.to!string);
            }
        }
        catch (ConvException e)
        {
            errorf("Unkown method name %s: %s!", methodName.to!string, e);
            return;
        }

        auto authorized = false;

        info("Tying to authorized user...");
        try
        {
            authorized = queryPolkitAuth(operation.toPolkitAction(), sender.to!string);
        }
        catch (GException e)
        {
            errorf("Authorization for operation %s for has failed due to error '%s'!", operation, e);
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.AUTH_FAILED,
                    format("Authorization for operation %s for has failed due to error '%s'!",
                        operation, e));
            return;
        }

        if (authorized)
        {
            info("Authorization succeeded!");
            Variant[] ret;
            auto databaseOperation = cast(ApkDataBaseOperations) operation;
            if (databaseOperation)
            {
                final switch (databaseOperation.val) with (ApkDataBaseOperations.Enum)
                {
                case addPackage:
                    auto pkgnames = variant.getChildValue(0).getStrv();
                    try
                    {
                        ApkInterfacer.addPackage(pkgnames, userData.root);
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
                    auto pkgnames = variant.getChildValue(0).getStrv();
                    try
                    {
                        ApkInterfacer.deletePackage(pkgnames, userData.root);
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
                    try
                    {
                        ret ~= apkPackageArrayToVariant(
                                ApkInterfacer.getAvailablePackages(userData.root));
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
                        ret ~= apkPackageArrayToVariant(
                                ApkInterfacer.getInstalledPackages(userData.root));
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
                    try
                    {
                        ret ~= apkPackageArrayToVariant(
                                ApkInterfacer.getUpgradablePackages(userData.root));

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
                    try
                    {
                        ApkInterfacer.updateRepositories(userData.root);
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
                        ApkInterfacer.upgradeAllPackages(userData.root);

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
                    auto pkgnames = variant.getChildValue(0).getStrv();
                    try
                    {
                        ApkInterfacer.upgradePackage(pkgnames, userData.root);
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
            }
            else
            {
                auto dbusOperation = cast(DBusPropertyOperations) operation;
                final switch (dbusOperation.val) with (DBusPropertyOperations.Enum)
                {
                case getAll:
                    auto builder = new VariantBuilder(new VariantType("a{sv}"));
                    builder.open(new VariantType("{sv}"));
                    builder.addValue(new Variant("allowUntrustedRepos"));
                    builder.addValue(new Variant(new Variant(userData.allowUntrustedRepositories)));
                    builder.close();
                    ret ~= builder.end();
                    break;
                case allowUntrustedRepos:
                    if (dbusOperation.direction == DBusPropertyOperations.DirectionEnum.get)
                    {
                        ret ~= new Variant(new Variant(userData.allowUntrustedRepositories));
                    }
                    else
                    {
                        auto connection = new DBusConnection(dbusConnection);
                        userData.allowUntrustedRepositories = variant.getChildValue(2)
                            .getVariant().getBoolean();
                        auto dictBuilder = new VariantBuilder(new VariantType("a{sv}"));
                        dictBuilder.open(new VariantType("{sv}"));
                        dictBuilder.addValue(new Variant("allowUntrustedRepos"));
                        dictBuilder.addValue(new Variant(
                                new Variant(userData.allowUntrustedRepositories)));
                        dictBuilder.close();
                        auto valBuilder = new VariantBuilder(new VariantType("(sa{sv}as)"));
                        valBuilder.addValue(new Variant(interfaceName.to!string));
                        valBuilder.addValue(dictBuilder.end());
                        valBuilder.open(new VariantType("as"));
                        valBuilder.addValue(new Variant(""));
                        valBuilder.close();
                        connection.emitSignal(null, objectPath.to!string,
                                "org.freedesktop.DBus.Properties",
                                "PropertiesChanged", valBuilder.end());
                    }
                    break;
                case root:
                    if (dbusOperation.direction == DBusPropertyOperations.DirectionEnum.get)
                    {
                        ret ~= new Variant(new Variant(userData.root));
                    }
                    else
                    {
                        auto connection = new DBusConnection(dbusConnection);
                        ulong len;
                        userData.root = variant.getChildValue(2).getVariant().getString(len);
                        auto dictBuilder = new VariantBuilder(new VariantType("a{sv}"));
                        dictBuilder.open(new VariantType("{sv}"));
                        dictBuilder.addValue(new Variant("root"));
                        dictBuilder.addValue(new Variant(new Variant(userData.root)));
                        dictBuilder.close();
                        auto valBuilder = new VariantBuilder(new VariantType("(sa{sv}as)"));
                        valBuilder.addValue(new Variant(interfaceName.to!string));
                        valBuilder.addValue(dictBuilder.end());
                        valBuilder.open(new VariantType("as"));
                        valBuilder.addValue(new Variant(""));
                        valBuilder.close();
                        connection.emitSignal(null, objectPath.to!string,
                                "org.freedesktop.DBus.Properties",
                                "PropertiesChanged", valBuilder.end());
                    }
                    break;
                }
            }

            auto retVariant = new Variant(ret);
            dbusInvocation.returnValue(retVariant);
        }
        else
        {
            error("Autorization failed!");
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.ACCESS_DENIED,
                    format("Authorization for operation %s for has failed for user!", operation));
        }
    }

    /**
    * Passed to GDBus to be executed once we've successfully established a connection to the
    * DBus bus. We register our methods here.
    */
    extern (C) static void onBusAcquired(GDBusConnection* gdbusConnection,
            const char*, void* userData)
    {
        trace("Acquired the DBus connection");
        auto interfaceVTable = GDBusInterfaceVTable(&methodHandler, null, null, null);
        auto dbusConnection = new DBusConnection(gdbusConnection);

        auto dbusIntrospectionData = new DBusNodeInfo(dbusIntrospectionXML);
        enforce(dbusIntrospectionData !is null);

        const auto regId = dbusConnection.registerObject(apkd_common.globals.dbusObjectPath,
                dbusIntrospectionData.interfaces[0], &interfaceVTable, userData, null);
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
    UserData userData;
}

/**
* Helper class that is used in DBusServer.handleMethod to call the right functions on
* apkd.ApkDatabase, handle logging etc.
*/
class ApkInterfacer
{
    static void updateRepositories(in string root = null)
    {
        trace("Trying to update repositories.");
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        dbGuard.db.updateRepositories(false);
        trace("Successfully updated repositories.");
    }

    static void upgradePackage(string[] pkgname, in string root = null)
    {
        tracef("Trying to upgrade package '%s'.", pkgname);
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        dbGuard.db.upgradePackage(pkgname);
        tracef("Successfully upgraded package%s '%s'.", pkgname.length > 1 ? "s" : "", pkgname);
    }

    static void upgradeAllPackages(in string root = null)
    {
        trace("Trying upgrade all packages.");
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        dbGuard.db.upgradeAllPackages();
        trace("Succesfully upgraded all packages.");
    }

    static void deletePackage(string[] pkgname, in string root = null)
    {
        tracef("Trying to delete package%s '%s'.", pkgname.length > 1 ? "s" : "", pkgname);
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        dbGuard.db.deletePackage(pkgname);
        tracef("Successfully deleted package%s '%s'.", pkgname.length > 1 ? "s" : "", pkgname);
    }

    static void addPackage(string[] pkgname, in string root = null)
    {
        tracef("Trying to add package%s: %s", pkgname.length > 1 ? "s" : "", pkgname);
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        dbGuard.db.addPackage(pkgname);
        tracef("Successfully added package%s '%s'.", pkgname.length > 1 ? "s" : "", pkgname);
    }

    static ApkPackage[] getAvailablePackages(in string root = null)
    {
        trace("Trying to list all available packages");
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        auto packages = dbGuard.db.getAvailablePackages();
        trace("Successfully listed all available packages");
        return packages;
    }

    static ApkPackage[] getInstalledPackages(in string root = null)
    {
        trace("Trying to list all installed packages");
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        auto packages = dbGuard.db.getInstalledPackages();
        trace("Successfully listed all installed packages");
        return packages;
    }

    static ApkPackage[] getUpgradablePackages(in string root = null)
    {
        trace("Trying to list upgradable packages");
        auto dbGuard = DatabaseGuard(root ? new ApkDataBase(root) : new ApkDataBase());
        auto packages = dbGuard.db.getUpgradablePackages();
        trace("Successfully listed all upgradable packages");
        return packages;
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
