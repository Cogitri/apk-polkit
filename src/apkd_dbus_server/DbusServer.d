/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://gitlab.alpinelinux.org/Cogitri/apk-polkit).

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
static import apkd.functions;
static import apkd_common.globals;
import apkd_dbus_server.Polkit;
import apkd_dbus_server.Util;
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
import glib.Idle;
import glib.MainContext;
import glib.MainLoop;
import glib.Source;
import glib.Thread;
import glib.Variant;
import glib.VariantBuilder;
import glib.VariantType;
import std.array : split;
import std.ascii : toLower, toUpper;
import std.conv : to, ConvException;
import std.concurrency : receive;
import std.datetime : SysTime;
import std.exception;
import std.experimental.logger;
import std.format : format;
import std.meta : AliasSeq;
import std.stdio : readln;
import std.string : chomp;
import std.traits : hasUDA, Parameters, ReturnType;

/**
* Different errors that might occur during operations. This is only
* used to send it back over DBus in case something goes wrong.
*/
enum ApkdDbusServerErrorQuarkEnum
{
    Failed,
    AddError,
    DeleteError,
    ListAvailableError,
    ListInstalledError,
    ListUpgradableError,
    SearchPackageNamesError,
    SearchFileOwnerError,
    UpdateRepositoriesError,
    UpgradePackageError,
    UpgradeAllPackagesError,
}

/**
* GQuark for our error domain
*/
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
    * Parameters:
    *   root    = The root of the database. Useful to install to places other than /
    */
    this(in string root = null)
    {
        tracef("Trying to acquire DBus name %s.", apkd_common.globals.dbusBusName);
        this.allowUntrustedRepositories = false;
        this.root = null;
        this.userData = UserData(null, null);
        auto dbusFlags = BusNameOwnerFlags.NONE;
        this.ownerId = DBusNames.ownName(BusType.SYSTEM, apkd_common.globals.dbusBusName,
                dbusFlags, &onBusAcquired, &onNameAcquired, &onNameLost,
                cast(void*) this, null);
    }

    ~this()
    {
        DBusNames.unownName(this.ownerId);
    }

    /**
    * Add (install) packages and send progress notifications via DBus.
    *
    * Params:
    *   pkgnames = Packages to add.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   Throws a BadDependencyFormatException if the format for the package name isn't valid.
    *   Throws a NoSuchpackageFoundException if the package name specified can't be found.
    *   Throws an ApkDatabaseCommitException if committing the changes to the database fails, e.g.
    *   due to missing permissions, a conflict, etc.
    */
    @("DBusMethod")
    void addPackages(DBusMethodInvocation dbusInvocation, Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
        try
        {
            tracef("Trying to add package%s: %s", pkgnames.length > 1 ? "s" : "", pkgnames);
            auto database = ApkDataBase(this.root);
            auto idleSource = this.connectProgressSignal(&database);
            scope (exit)
            {
                idleSource.destroy();
            }
            database.addPackages(pkgnames);
            tracef("Successfully added package%s '%s'.", pkgnames.length > 1 ? "s" : "", pkgnames);
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(), ApkdDbusServerErrorQuarkEnum.AddError,
                    format("Couldn't add package%s %s due to error %s",
                        pkgnames.length == 0 ? "" : "s", pkgnames, e.msg));
        }
    }

    /**
    * Delete (uninstall) packages and send progress notifications via DBus.
    *
    * Params:
    *   pkgnames = Packages to delete.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   Throws an ApkException if something went wrong while trying to delete packages, e.g.
    *   due to being unable to find the requested package name.
    *   Throws an ApkSolverException if the solver can't figure out a way to solve
    *   the deletion, e.g. due to conflicts.
    *   Throws an ApkDatabaseCommitException if committing the changes to the database fails, e.g.
    *   due to missing permissions.
    */
    @("DBusMethod")
    void deletePackages(DBusMethodInvocation dbusInvocation, Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
        try
        {
            tracef("Trying to delete package%s '%s'.", pkgnames.length > 1 ? "s" : "", pkgnames);
            auto database = ApkDataBase(this.root);
            auto idleSource = this.connectProgressSignal(&database);
            scope (exit)
            {
                idleSource.destroy();
            }
            database.deletePackages(pkgnames);
            tracef("Successfully deleted package%s '%s'.", pkgnames.length > 1 ? "s" : "", pkgnames);
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(), ApkdDbusServerErrorQuarkEnum.DeleteError,
                    format("Couldn't delete package%s %s due to error %s",
                        pkgnames.length == 0 ? "" : "s", pkgnames, e.msg));
        }
    }

    @("DBusMethod")
    Variant getAll()
    {
        auto builder = new VariantBuilder(new VariantType("a{sv}"));

        builder.open(new VariantType("{sv}"));
        builder.addValue(new Variant("allowUntrustedRepos"));
        builder.addValue(new Variant(new Variant(this.allowUntrustedRepositories)));
        builder.close();

        builder.open(new VariantType("{sv}"));
        builder.addValue(new Variant("root"));
        builder.addValue(new Variant(new Variant(this.root ? this.root : "")));
        builder.close();

        return builder.end();
    }

    @("DBusMethod")
    Variant getAllowUntrustedRepos()
    {
        return new Variant(new Variant(this.allowUntrustedRepositories));
    }

    @("DBusMethod")
    Variant getRoot()
    {
        return new Variant(new Variant(this.root));
    }

    /**
    * Get an array of all available packages. This also includes already installed packages.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   An ApkListException if something went wrong in iterating over packages
    */
    @("DBusMethod")
    Variant listAvailablePackages(DBusMethodInvocation dbusInvocation)
    {
        try
        {
            trace("Trying to list all available packages");
            auto database = ApkDataBase(this.root);
            auto packages = database.listAvailablePackages();
            trace("Successfully listed all available packages");
            return apkPackageArrayToVariant(packages);
        }

        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.ListAvailableError,
                    format("Couldn't list available packages due to error %s", e.msg));
            return null;
        }
    }

    /**
    * Get an array of all packages that are installed on the machine.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    */
    @("DBusMethod")
    Variant listInstalledPackages(DBusMethodInvocation dbusInvocation)
    {
        try
        {
            trace("Trying to list all installed packages");
            auto database = ApkDataBase(this.root);
            auto packages = database.listInstalledPackages();
            trace("Successfully listed all installed packages");
            return apkPackageArrayToVariant(packages);
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.ListInstalledError,
                    format("Couldn't list installable packages due to error %s", e.msg));
            return null;
        }
    }

    /**
    * Get an array of all packages that can be upgraded on the machine.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   An ApkListException if something went wrong in iterating over packages
    */
    @("DBusMethod")
    Variant listUpgradablePackages(DBusMethodInvocation dbusInvocation)
    {
        try
        {
            trace("Trying to list upgradable packages");
            auto database = ApkDataBase(this.root);
            auto packages = database.listUpgradablePackages();
            trace("Successfully listed all upgradable packages");
            return apkPackageArrayToVariant(packages);
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.ListUpgradableError,
                    format("Couldn't list upgradable packages due to error %s", e.msg));
            return null;
        }
    }

    /**
    * Update all repositories available and send progress notifications via DBus.
    *
    * Params:
    *   allowUntrustedRepositories = True if repos without a trusted key should be used
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   Throws a BadDependencyFormatException if the format for the package name isn't valid.
    *   Throws a NoSuchpackageFoundException if the package name specified can't be found.
    *   Throws an ApkDatabaseCommitException if committing the changes to the database fails, e.g.
    *   due to missing permissions, a conflict, etc.
    *
    */
    @("DBusMethod")
    void updateRepositories(DBusMethodInvocation dbusInvocation)
    {
        try
        {
            trace("Trying to update repositories.");
            auto database = ApkDataBase(this.root);
            auto idleSource = this.connectProgressSignal(&database);
            scope (exit)
            {
                idleSource.destroy();
            }
            database.updateRepositories(this.allowUntrustedRepositories);
            trace("Successfully updated repositories.");
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.UpdateRepositoriesError,
                    format("Couldn't update repositories due to error %s", e.msg));
            return;
        }
    }

    /**
    * Upgrade all packages
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   Throws an ApkSolverException if the solver can't figure out a way to solve
    *   the upgrade, e.g. due to conflicts.
    */
    @("DBusMethod")
    void upgradeAllPackages(DBusMethodInvocation dbusInvocation)
    {
        try
        {
            trace("Trying upgrade all packages.");
            auto database = ApkDataBase(this.root);
            auto idleSource = this.connectProgressSignal(&database);
            scope (exit)
            {
                idleSource.destroy();
            }
            database.upgradeAllPackages();
            trace("Successfully upgraded all packages.");
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.UpgradeAllPackagesError,
                    format("Couldn't upgrade all packages due to error %s", e.msg));
            return;
        }
    }

    /**
    * Upgrade packages and send progress notifications via DBus.
    *
    * Params:
    *   pkgnames = Packages to upgrade. Keep in mind that apk will also upgrade dependencies of that package.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   Throws a BadDependencyFormatException if the format for the package name isn't valid.
    *   Throws a NoSuchpackageFoundException if the package name specified can't be found.
    *   Throws an ApkDatabaseCommitException if commiting the changes to the database fails, e.g.
    *   due to missing permissions, a conflict, etc.
    */
    @("DBusMethod")
    void upgradePackages(DBusMethodInvocation dbusInvocation, Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
        try
        {
            tracef("Trying to upgrade package '%s'.", pkgnames);
            auto database = ApkDataBase(this.root);
            auto idleSource = this.connectProgressSignal(&database);
            scope (exit)
            {
                idleSource.destroy();
            }
            database.upgradePackages(pkgnames);
            tracef("Successfully upgraded package%s '%s'.", pkgnames.length > 1 ? "s" : "",
                    pkgnames);
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.UpgradePackageError,
                    format("Couldn't upgrade package%s %s due to error %s",
                        pkgnames.length == 0 ? "" : "s", pkgnames, e.msg));
            return;
        }
    }

    /**
    * Get an array of all packages that match one of the pkgnames given. Uses substring searching.
    *
    * Params:
    *   pkgnames = pkgnames to search for
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   An ApkListException if something went wrong in iterating over packages
    */
    @("DBusMethod")
    Variant searchFileOwner(DBusMethodInvocation dbusInvocation, Variant parameters)
    {
        try
        {
            size_t len;
            auto path = parameters.getChildValue(0).getString(len);
            tracef("Trying to search owner of path %s", path);
            auto database = ApkDataBase(this.root);
            auto matchedPackage = database.searchFileOwner(path);
            trace("Successfully searched for package");
            return apkPackageToVariant(matchedPackage);
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.SearchFileOwnerError,
                    format("Couldn't search for owner of file due to error %s", e.msg));
            return null;
        }
    }

    /**
    * Get an array of all packages that match one of the pkgnames given. Uses substring searching.
    *
    * Params:
    *   pkgnames = pkgnames to search for
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   An ApkListException if something went wrong in iterating over packages
    */
    @("DBusMethod")
    Variant searchPackageNames(DBusMethodInvocation dbusInvocation, Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
        try
        {
            tracef("Trying to search for packages %s", pkgnames);
            auto database = ApkDataBase(this.root);
            auto packages = database.searchPackageNames(pkgnames);
            tracef("Successfully searched for packages. %s hits.", packages.length);
            return apkPackageArrayToVariant(packages);
        }
        catch (Exception e)
        {
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.SearchPackageNamesError,
                    format("Couldn't search for packages due to error %s", e.msg));
            return null;
        }
    }

    @("DBusMethod")
    void setAllowUntrustedRepos(Variant value)
    {
        this.allowUntrustedRepositories = value.getChildValue(2).getVariant().getBoolean();

        if (this.allowUntrustedRepositories)
        {
            apkd.functions.allowUntrusted();
        }
        else
        {
            apkd.functions.disallowUntrusted();
        }

        auto dictBuilder = new VariantBuilder(new VariantType("a{sv}"));
        dictBuilder.open(new VariantType("{sv}"));
        dictBuilder.addValue(new Variant("allowUntrustedRepos"));
        dictBuilder.addValue(new Variant(new Variant(this.allowUntrustedRepositories)));
        dictBuilder.close();

        auto valBuilder = new VariantBuilder(new VariantType("(sa{sv}as)"));
        valBuilder.addValue(new Variant("org.freedesktop.DBus.Properties"));
        valBuilder.addValue(dictBuilder.end());
        valBuilder.open(new VariantType("as"));
        valBuilder.addValue(new Variant(""));
        valBuilder.close();

        this.userData.dbusConnection.emitSignal(null, "/dev/Cogitri/apkPolkit/Helper",
                "org.freedesktop.DBus.Properties", "PropertiesChanged", valBuilder.end());
    }

    @("DBusMethod")
    void setRoot(Variant value)
    {
        size_t len;
        this.root = value.getChildValue(2).getVariant().getString(len);

        auto dictBuilder = new VariantBuilder(new VariantType("a{sv}"));
        dictBuilder.open(new VariantType("{sv}"));
        dictBuilder.addValue(new Variant("root"));
        dictBuilder.addValue(new Variant(new Variant(this.root)));
        dictBuilder.close();

        auto valBuilder = new VariantBuilder(new VariantType("(sa{sv}as)"));
        valBuilder.addValue(new Variant("org.freedesktop.DBus.Properties"));
        valBuilder.addValue(dictBuilder.end());
        valBuilder.open(new VariantType("as"));
        valBuilder.addValue(new Variant(""));
        valBuilder.close();

        this.userData.dbusConnection.emitSignal(null, "/dev/Cogitri/apkPolkit/Helper",
                "org.freedesktop.DBus.Properties", "PropertiesChanged", valBuilder.end());
    }

    static bool checkAuth(string operation, string sender, DBusMethodInvocation dbusInvocation)
    {
        info("Tying to authorized user...");
        try
        {
            return queryPolkitAuth(operation, sender.to!string);
        }
        catch (GException e)
        {
            errorf("Authorization for operation %s for has failed due to error '%s'!",
                    operation, e.msg);
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.AUTH_FAILED,
                    format("Authorization for operation %s for has failed due to error '%s'!",
                        operation, e.msg));
            return false;
        }
    }

    /**
    * Passed to GDBus to handle incoming method calls. In this function we match the method name to the function to be
    * executed, authorize the user via polkit and send the return value back. We try very hard not to throw here and
    * instead send a dbus error message back and return early, since throwing here would mean crashing the entire server.
    */
    extern (C) static void methodHandler(GDBusConnection* dbusConnection,
            const char* sender, const char* objectPath, const char* interfaceName,
            const char* rawMethodName, GVariant* parameters,
            GDBusMethodInvocation* invocation, void* userDataPtr)
    in
    {
        assert(cast(DBusServer*) userDataPtr);
    }
    do
    {
        tracef("Handling method %s from sender %s", rawMethodName.to!string, sender.to!string);
        auto dbusInvocation = new DBusMethodInvocation(invocation);
        auto dbusServer = cast(DBusServer) userDataPtr;
        dbusServer.userData.dbusConnection = new DBusConnection(dbusConnection);
        Variant[] ret = [];
        auto parametersVariant = new Variant(parameters);
        auto methodName = rawMethodName.to!string;

        string propertyName = "";
        if (interfaceName.to!string == "org.freedesktop.DBus.Properties")
        {
            if (parametersVariant.nChildren() > 1)
            {
                size_t len;
                propertyName = parametersVariant.getChildValue(1).getString(len);
                propertyName = propertyName[0].toUpper() ~ propertyName[1 .. $];
            }
        }

    methsw:
        switch (methodName[0].toLower() ~ methodName[1 .. $] ~ propertyName)
        {
            static foreach (memberName; __traits(allMembers, DBusServer))
            {
                static if (mixin("hasUDA!(DBusServer." ~ memberName ~ ", \"DBusMethod\")"))
                {
        case memberName:
                    if (checkAuth("dev.Cogitri.apkPolkit.Helper." ~ memberName,
                            sender.to!string, dbusInvocation))
                    {
                        static if (!is(ReturnType!((__traits(getMember,
                                DBusServer, memberName))) == void))
                        {
                            immutable retString = "ret ~=";
                        }
                        else
                        {
                            immutable retString = "";
                        }
                        mixin(retString ~ " dbusServer." ~ Call!(mixin("dbusServer." ~ memberName)));
                    }
                    else
                    {
                        dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(), DBusError.ACCESS_DENIED,
                                "Authorization for operation" ~ memberName
                                ~ "for has failed for user!");
                        return;
                    }
                    break methsw;
                }
            }

        default:
            errorf("Unkown method name %s", methodName);
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(),
                    DBusError.NOT_SUPPORTED, format("Unkown method name %s", methodName));
            return;
        }

        auto retVariant = new Variant(ret);
        dbusInvocation.returnValue(retVariant);
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
    static Variant apkPackageToVariant(ApkPackage pkg)
    {
        auto pkgBuilder = new VariantBuilder(new VariantType("(sssssssssssttxb)"));
        static foreach (member; [
                "name", "newVersion", "oldVersion", "arch", "license", "origin",
                "maintainer", "url", "description", "commit", "filename"
            ])
        {
            pkgBuilder.addValue(new Variant(__traits(getMember, pkg, member)
                    ? __traits(getMember, pkg, member) : ""));
        }
        static foreach (member; ["installedSize", "size"])
        {
            pkgBuilder.addValue(new Variant(__traits(getMember, pkg, member)));
        }
        pkgBuilder.addValue(new Variant(pkg.buildTime.toUnixTime!long()));
        pkgBuilder.addValue(new Variant(pkg.isInstalled));
        return pkgBuilder.end();
    }

    /// Helper method to convert a ApkPackage array to a Variant for sending it over DBus
    static Variant apkPackageArrayToVariant(ApkPackage[] pkgArr)
    {
        auto arrBuilder = new VariantBuilder(new VariantType("a(sssssssssssttxb)"));
        foreach (pkg; pkgArr)
        {
            arrBuilder.addValue(apkPackageToVariant(pkg));
        }

        return arrBuilder.end();
    }

    /// Passed to  progressSenderFn as userData
    struct InterfacerUserData
    {
        ApkDataBase* db;
        DBusConnection connection;
    }

    /**
    * Start the thread that sends progress notifications while our
    * main thread is busy running the actual database operation
    */
    extern (C) static void* startProgressWorkerThread(void* contextPtr)
    {
        auto context = new MainContext(cast(GMainContext*) contextPtr);
        context.pushThreadDefault();
        auto mainLoop = new MainLoop(context, false);
        mainLoop.run();
        context.popThreadDefault();
        context.unref();
        return null;
    }

    /// Sends progressNotification signal
    extern (C) static int progressSenderFn(void* userData)
    {
        auto interfacerUserData = cast(InterfacerUserData*) userData;
        const auto progress = interfacerUserData.db.progressFd.readln().chomp().split('/');
        float percentage;
        // If we didn't hear back from APK, assume we don't have any progress
        if (progress.length == 0)
        {
            return G_SOURCE_CONTINUE;
        }
        else
        {
            auto done = progress[0].to!uint;
            auto total = progress[1].to!uint;
            // We can't dive through 0
            if (total == 0)
            {
                percentage = 0;
            }
            else
            {
                percentage = (done.to!float / total.to!float) * 100;
            }
        }
        interfacerUserData.connection.emitSignal(null, apkd_common.globals.dbusObjectPath,
                apkd_common.globals.dbusInterfaceName, "progressNotification",
                new Variant([new Variant(percentage.to!uint)]));
        return G_SOURCE_CONTINUE;
    }

    /// Connect a Database's progress pipe to our DBus progressNotification signal
    Source connectProgressSignal(ApkDataBase* db)
    {
        this.userData.db = db;
        auto mainContext = new MainContext();
        auto progressWorkerThread = new Thread("progressWorker",
                &startProgressWorkerThread, mainContext.getMainContextStruct());

        auto idleSource = Idle.sourceNew();
        idleSource.setCallback(&progressSenderFn, &this.userData, null);
        idleSource.setPriority(G_PRIORITY_HIGH);
        idleSource.attach(mainContext);
        return idleSource;
    }

    struct UserData
    {
        ApkDataBase* db;
        DBusConnection dbusConnection;
    }

    bool allowUntrustedRepositories;
    string root;
    uint ownerId;
    UserData userData;
}
