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
import apkd.ApkRepository;
import apkd.exceptions;
static import apkd.functions;
import apkd_common.gettext : gettext;
static import apkd_common.globals;
import apkd_dbus_server.DbusMethodRegistrar;
import apkd_dbus_server.OperationErrorTranslator;
import apkd_dbus_server.Polkit;
import gio.Cancellable;
import gio.DBusConnection;
static import gio.DBusError;
import gio.DBusMethodInvocation;
import gio.DBusNames;
import gio.DBusNodeInfo;
import glib.c.functions;
import glib.GException;
import glib.Idle;
import glib.MainContext;
import glib.MainLoop;
import glib.Source;
import glib.Thread;
import glib.Variant;
import glib.VariantBuilder;
import glib.VariantType;
import std.algorithm : canFind, find, remove;
import std.array : split;
import std.ascii : toLower, toUpper;
import std.concurrency : receive;
import std.conv : ConvException, to;
import std.datetime : SysTime;
import std.exception;
import std.experimental.logger;
import std.format : format;
import std.meta : AliasSeq;
import std.path : buildPath;
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

string registerDbusMethod(string methodName)
{
    return "DbusMethodRegistrar.getInstance().register(&" ~ methodName ~ ", \"" ~ methodName
        ~ "\");";
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
    this(in bool replace, in string root = null)
    {
        tracef("Trying to acquire DBus name %s.", apkd_common.globals.dbusBusName);

        mixin(registerDbusMethod("addPackages"));
        mixin(registerDbusMethod("addRepository"));
        mixin(registerDbusMethod("deletePackages"));
        mixin(registerDbusMethod("getAll"));
        mixin(registerDbusMethod("getAllowUntrustedRepos"));
        mixin(registerDbusMethod("getRoot"));
        mixin(registerDbusMethod("listAvailablePackages"));
        mixin(registerDbusMethod("listInstalledPackages"));
        mixin(registerDbusMethod("listRepositories"));
        mixin(registerDbusMethod("listUpgradablePackages"));
        mixin(registerDbusMethod("removeRepository"));
        mixin(registerDbusMethod("searchFileOwner"));
        mixin(registerDbusMethod("searchPackageNames"));
        mixin(registerDbusMethod("setAllowUntrustedRepos"));
        mixin(registerDbusMethod("setRoot"));
        mixin(registerDbusMethod("updateRepositories"));
        mixin(registerDbusMethod("upgradeAllPackages"));
        mixin(registerDbusMethod("upgradePackages"));

        this.userData = UserData(null, null);
        const dbusFlags = BusNameOwnerFlags.ALLOW_REPLACEMENT | (replace
                ? BusNameOwnerFlags.REPLACE : BusNameOwnerFlags.NONE);
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
    void addPackages(Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
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

    /**
    * Adds a repository to /etc/apk/repositories.
    *
    * Throws:
    *   An ErrnoException if opening/writing to the file fails.
    */
    void addRepository(Variant value)
    {
        size_t len;
        const repoUrl = value.getChildValue(0).getString(len);
        const reposFilePath = this.root ? buildPath(this.root, "etc", "apk",
                "repositories") : "/etc/apk/repositories";

        tracef("Adding repository '%s' to file '%s'.", repoUrl, reposFilePath);
        auto repos = ApkDataBase.getRepositories(reposFilePath);
        if (repos.canFind!(r => r.enabled && r.url == repoUrl))
        {
            infof("Didn't add repository '%s', since it already is in /etc/apk/repositories",
                    repoUrl);
            return;
        }
        ApkDataBase.setRepositories(repos ~ ApkRepository(repoUrl, true), reposFilePath);
        tracef("Successfully added repository %s.", repoUrl);
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
    void deletePackages(Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
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

    Variant getAll()
    {
        GVariantBuilder builder;
        g_variant_builder_init(&builder, new VariantType("a{sv}").getVariantTypeStruct(true));
        scope (exit)
        {
            g_variant_builder_clear(&builder);
        }

        auto variantType = new VariantType("{sv}");
        g_variant_builder_open(&builder, variantType.getVariantTypeStruct(false));
        g_variant_builder_add_value(&builder,
                new Variant("allowUntrustedRepos").getVariantStruct(true));
        g_variant_builder_add_value(&builder, this.getAllowUntrustedRepos()
                .getVariantStruct(true));
        g_variant_builder_close(&builder);
        g_variant_builder_open(&builder, variantType.getVariantTypeStruct(false));
        g_variant_builder_add_value(&builder, new Variant("root").getVariantStruct(true));
        g_variant_builder_add_value(&builder, new Variant(new Variant(this.root
                ? this.root : "")).getVariantStruct(true));
        g_variant_builder_close(&builder);

        return new Variant(g_variant_builder_end(&builder));
    }

    Variant getAllowUntrustedRepos()
    {
        return new Variant(new Variant(this.allowUntrustedRepositories));
    }

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
    Variant listAvailablePackages()
    {
        trace("Trying to list all available packages");
        auto database = ApkDataBase(this.root);
        auto packages = database.listAvailablePackages();
        trace("Successfully listed all available packages");
        return apkPackageArrayToVariant(packages);
    }

    /**
    * Get an array of all packages that are installed on the machine.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    */
    Variant listInstalledPackages()
    {
        trace("Trying to list all installed packages");
        auto database = ApkDataBase(this.root);
        auto packages = database.listInstalledPackages();
        trace("Successfully listed all installed packages");
        return apkPackageArrayToVariant(packages);
    }

    /**
    * Lists all repositories in /etc/apk/repositories.
    *
    * Throws:
    *   An ErrnoException if opening/reading from the file fails.
    */
    Variant listRepositories()
    {
        const reposFilePath = this.root ? buildPath(this.root, "etc", "apk",
                "repositories") : "/etc/apk/repositories";
        trace("Trying to list repositories from file '%s'", reposFilePath);

        const auto repos = ApkDataBase.getRepositories(reposFilePath);
        auto builder = new VariantBuilder(new VariantType("a(bss)"));

        foreach (ref repo; repos)
        {
            warning(repo);
            builder.open(new VariantType("(bss)"));

            builder.addValue(new Variant(repo.enabled));
            builder.addValue(new Variant(new Variant(repo.description
                    ? repo.description : "").getVariantStruct()));
            builder.addValue(new Variant(repo.url));

            builder.close();
        }

        return builder.end();
    }

    /**
    * Get an array of all packages that can be upgraded on the machine.
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   An ApkListException if something went wrong in iterating over packages
    */
    Variant listUpgradablePackages()
    {
        trace("Trying to list upgradable packages");
        auto database = ApkDataBase(this.root);
        auto packages = database.listUpgradablePackages();
        trace("Successfully listed all upgradable packages");
        return apkPackageArrayToVariant(packages);
    }

    /**
    * Removes a repository from /etc/apk/repositories.
    *
    * Throws:
    *   An ErrnoException if opening/writing to the file fails.
    */
    void removeRepository(Variant value)
    {
        size_t len;
        const repoUrl = value.getChildValue(0).getString(len);
        const reposFilePath = this.root ? buildPath(this.root, "etc", "apk",
                "repositories") : "/etc/apk/repositories";

        tracef("Removing repository '%s' from file '%s'.", repoUrl, reposFilePath);
        auto repos = ApkDataBase.getRepositories(reposFilePath);
        repos = repos.remove!(repo => repo.enabled && repo.url == repoUrl);
        ApkDataBase.setRepositories(repos, reposFilePath);
        tracef("Successfully removed repository %s.", repoUrl);
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
    void updateRepositories()
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

    /**
    * Upgrade all packages
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    *   Throws an ApkSolverException if the solver can't figure out a way to solve
    *   the upgrade, e.g. due to conflicts.
    */
    void upgradeAllPackages()
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
    void upgradePackages(Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
        tracef("Trying to upgrade package '%s'.", pkgnames);
        auto database = ApkDataBase(this.root);
        auto idleSource = this.connectProgressSignal(&database);
        scope (exit)
        {
            idleSource.destroy();
        }
        database.upgradePackages(pkgnames);
        tracef("Successfully upgraded package%s '%s'.", pkgnames.length > 1 ? "s" : "", pkgnames);
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
    Variant searchFileOwner(Variant parameters)
    {
        size_t len;
        auto path = parameters.getChildValue(0).getString(len);
        tracef("Trying to search owner of path %s", path);
        auto database = ApkDataBase(this.root);
        auto matchedPackage = database.searchFileOwner(path);
        trace("Successfully searched for package");
        return apkPackageToVariant(matchedPackage);
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
    Variant searchPackageNames(Variant parameters)
    {
        auto pkgnames = parameters.getChildValue(0).getStrv();
        tracef("Trying to search for packages %s", pkgnames);
        auto database = ApkDataBase(this.root);
        auto packages = database.searchPackageNames(pkgnames);
        tracef("Successfully searched for packages. %s hits.", packages.length);
        return apkPackageArrayToVariant(packages);
    }

    void setAllowUntrustedRepos(Variant value)
    {
        GVariantBuilder dictBuilder;
        GVariantBuilder valBuilder;

        this.allowUntrustedRepositories = value.getChildValue(2).getVariant().getBoolean();

        if (this.allowUntrustedRepositories)
        {
            apkd.functions.allowUntrusted();
        }
        else
        {
            apkd.functions.disallowUntrusted();
        }

        g_variant_builder_init(&dictBuilder, new VariantType("a{sv}").getVariantTypeStruct(true));
        scope (exit)
        {
            g_variant_builder_clear(&dictBuilder);
        }
        g_variant_builder_open(&dictBuilder, new VariantType("{sv}").getVariantTypeStruct(true));
        g_variant_builder_add_value(&dictBuilder,
                new Variant("allowUntrustedRepos").getVariantStruct(true));
        g_variant_builder_add_value(&dictBuilder,
                new Variant(new Variant(this.allowUntrustedRepositories)).getVariantStruct(true));
        g_variant_builder_close(&dictBuilder);

        g_variant_builder_init(&valBuilder, new VariantType("(sa{sv}as)")
                .getVariantTypeStruct(true));
        scope (exit)
        {
            g_variant_builder_clear(&valBuilder);
        }
        g_variant_builder_add_value(&valBuilder,
                new Variant("org.freedesktop.DBus.Properties").getVariantStruct(true));
        g_variant_builder_add_value(&valBuilder, g_variant_builder_end(&dictBuilder));
        g_variant_builder_open(&valBuilder, new VariantType("as").getVariantTypeStruct(true));
        g_variant_builder_add_value(&valBuilder, new Variant("").getVariantStruct(true));
        g_variant_builder_close(&valBuilder);

        this.userData.dbusConnection.emitSignal(null,
                "/dev/Cogitri/apkPolkit/Helper", "org.freedesktop.DBus.Properties",
                "PropertiesChanged", new Variant(g_variant_builder_end(&valBuilder)));
    }

    void setRoot(Variant value)
    {
        GVariantBuilder dictBuilder;
        GVariantBuilder valBuilder;
        size_t len;
        this.root = value.getChildValue(2).getVariant().getString(len);

        g_variant_builder_init(&dictBuilder, new VariantType("a{sv}").getVariantTypeStruct(true));
        scope (exit)
        {
            g_variant_builder_clear(&dictBuilder);
        }
        g_variant_builder_open(&dictBuilder, new VariantType("{sv}").getVariantTypeStruct(true));
        g_variant_builder_add_value(&dictBuilder, new Variant("root").getVariantStruct(true));
        g_variant_builder_add_value(&dictBuilder,
                new Variant(new Variant(this.root)).getVariantStruct(true));
        g_variant_builder_close(&dictBuilder);

        g_variant_builder_init(&valBuilder, new VariantType("(sa{sv}as)")
                .getVariantTypeStruct(true));
        scope (exit)
        {
            g_variant_builder_clear(&valBuilder);
        }
        g_variant_builder_add_value(&valBuilder,
                new Variant("org.freedesktop.DBus.Properties").getVariantStruct(true));
        g_variant_builder_add_value(&valBuilder, g_variant_builder_end(&dictBuilder));
        g_variant_builder_open(&valBuilder, new VariantType("as").getVariantTypeStruct(true));
        g_variant_builder_add_value(&valBuilder, new Variant("").getVariantStruct(true));
        g_variant_builder_close(&valBuilder);

        this.userData.dbusConnection.emitSignal(null,
                "/dev/Cogitri/apkPolkit/Helper", "org.freedesktop.DBus.Properties",
                "PropertiesChanged", new Variant(g_variant_builder_end(&valBuilder)));
    }

    static ulong getNumOfPackages(Variant params)
    {
        try
        {
            if (params.nChildren() < 1)
            {
                return 0;
            }
            else
            {
                return params.getChildValue(0).getStrv().length;
            }
        }
        catch (Exception e)
        {
            return 0;
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

        methodName = methodName[0].toLower() ~ methodName[1 .. $] ~ propertyName;

        try
        {
            const polkitResult = queryPolkitAuth("dev.Cogitri.apkPolkit.Helper." ~ methodName,
                    sender.to!string);
            if (!polkitResult)
            {
                const opErrorTranslator = new OperationErrorTranslator(methodName);
                immutable errMsg = format(opErrorTranslator.translateOperationError(
                        /* Translators: Couldn't add package due to error "access denied" */
                        cast(uint) DBusServer.getNumOfPackages(parametersVariant)),
                        gettext("access denied"));
                error(errMsg);
                dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(),
                        DBusError.ACCESS_DENIED, errMsg);
                return;
            }
        }
        catch (Exception e)
        {
            const opErrorTranslator = new OperationErrorTranslator(methodName);
            immutable errMsg = format(opErrorTranslator.translateAuthError(
                    cast(uint) DBusServer.getNumOfPackages(parametersVariant)), e.msg);
            error(errMsg);
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(),
                    DBusError.AUTH_FAILED, errMsg);
            return;
        }

        auto dbusMethodRegistar = DbusMethodRegistrar.getInstance();
        Variant dbusRes;
        try
        {
            dbusRes = dbusMethodRegistar.call(methodName, parametersVariant);
        }
        catch (DbusMethodNotFoundException e)
        {
            error(e.msg);
            dbusInvocation.returnErrorLiteral(gio.DBusError.DBusError.quark(),
                    DBusError.NOT_SUPPORTED, e.msg);
            return;
        }
        catch (Exception e)
        {
            const opErrorTranslator = new OperationErrorTranslator(methodName);
            immutable errMsg = format(opErrorTranslator.translateOperationError(
                    cast(uint) DBusServer.getNumOfPackages(parametersVariant)), e.msg);
            error(errMsg);
            dbusInvocation.returnErrorLiteral(ApkdDbusServerErrorQuark(),
                    ApkdDbusServerErrorQuarkEnum.Failed, errMsg);
            return;
        }
        if (dbusRes)
        {
            ret ~= dbusRes;
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
        GVariantBuilder pkgBuilder;
        g_variant_builder_init(&pkgBuilder, new VariantType("(ssssssttb)")
                .getVariantTypeStruct(true));

        scope (exit)
        {
            g_variant_builder_clear(&pkgBuilder);
        }

        static foreach (member; [
                "name", "newVersion", "oldVersion", "license", "url",
                "description"
            ])
        {
            g_variant_builder_add_value(&pkgBuilder, new Variant(__traits(getMember, pkg,
                    member) ? __traits(getMember, pkg, member) : "").getVariantStruct(true));
        }
        static foreach (member; ["installedSize", "size"])
        {
            g_variant_builder_add_value(&pkgBuilder,
                    new Variant(__traits(getMember, pkg, member)).getVariantStruct(true));
        }
        g_variant_builder_add_value(&pkgBuilder, new Variant(pkg.isInstalled)
                .getVariantStruct(true));
        return new Variant(g_variant_builder_end(&pkgBuilder));
    }

    /// Helper method to convert a ApkPackage array to a Variant for sending it over DBus
    static Variant apkPackageArrayToVariant(ApkPackage[] pkgArr)
    {
        GVariantBuilder arrBuilder;
        g_variant_builder_init(&arrBuilder, new VariantType("a(ssssssttb)")
                .getVariantTypeStruct(true));
        scope (exit)
        {
            g_variant_builder_clear(&arrBuilder);
        }
        foreach (ref pkg; pkgArr)
        {
            g_variant_builder_add_value(&arrBuilder, apkPackageToVariant(pkg)
                    .getVariantStruct(true));
        }

        return new Variant(g_variant_builder_end(&arrBuilder));
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
            const done = progress[0].to!uint;
            const total = progress[1].to!uint;
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
        new Thread("progressWorker", &startProgressWorkerThread,
                mainContext.getMainContextStruct());

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
    uint ownerId;
    string root;
    UserData userData;
}
