module apkd_dbus_server.DBusServer;

import apkd.ApkDataBase;
import apkd.exceptions;
import apkd_dbus_server.Polkit;
import ddbus;
import ddbus.c_lib : dbus_bus_get_unique_name;
import gio.Cancellable;
import std.conv : to;
import std.concurrency : receive;
import std.exception;
import std.experimental.logger;
import std.process : thisThreadID;

class DBusServer
{
    this(Connection conn)
    {
        auto msgRouter = new MessageRouter();

        auto objectPath = ObjectPath("/dev/Cogitri/apkPolkit/Helper");
        auto interfaceName = interfaceName("dev.Cogitri.apkPolkit.Helper");
        auto busName = busName("dev.Cogitri.apkPolkit.Helper");
        auto uniqueDbusName = dbus_bus_get_unique_name(conn.conn).to!string;
        auto apkInterfacer = new ApkInterfacer(uniqueDbusName);
        registerMethods(msgRouter, objectPath, interfaceName, apkInterfacer);
        registerRouter(conn, msgRouter);
        enforce(requestName(conn, busName));
    }
}

class ApkInterfacer
{
    this(string uniqueDbusName)
    {
        this.uniqueDbusName = uniqueDbusName;
    }

    bool updateRepositories()
    {
        trace("Trying to update repositories");

        auto cancellable = new Cancellable();
        auto polkitAuthSucceeded = queryPolkitAuth("dev.Cogitri.apkPolkit.update",
                this.uniqueDbusName, cancellable);
        if (polkitAuthSucceeded)
        {
            auto dbGuard = DatabaseGuard(new ApkDataBase());
            return dbGuard.db.updateRepositories(false);
        }
        else
        {
            return false;
        }
    }

    bool upgradePackage(string pkgname)
    {
        tracef("Trying to upgrade package '%s'", pkgname);

        auto cancellable = new Cancellable();
        auto polkitAuthSucceeded = queryPolkitAuth("dev.Cogitri.apkPolkit.upgrade",
                this.uniqueDbusName, cancellable);
        if (polkitAuthSucceeded)
        {
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
        else
        {
            return false;
        }
    }

    bool upgradeAllPackages()
    {

        trace("Trying upgrade all packages");
        auto cancellable = new Cancellable();
        auto polkitAuthSucceeded = queryPolkitAuth("dev.Cogitri.apkPolkit.upgrade",
                this.uniqueDbusName, cancellable);
        if (polkitAuthSucceeded)
        {
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
        else
        {
            return false;
        }
    }

    bool deletePackage(string pkgname)
    {
        tracef("Trying to delete package %s", pkgname);
        auto cancellable = new Cancellable();
        auto polkitAuthSucceeded = queryPolkitAuth("dev.Cogitri.apkPolkit.delete",
                this.uniqueDbusName, cancellable);
        if (polkitAuthSucceeded)
        {
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
        else
        {
            return false;
        }
    }

    bool addPackage(string pkgname)
    {
        tracef("Trying to add package: %s", pkgname);
        auto cancellable = new Cancellable();
        auto polkitAuthSucceeded = queryPolkitAuth("dev.Cogitri.apkPolkit.install",
                this.uniqueDbusName, cancellable);
        if (polkitAuthSucceeded)
        {
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
        else
        {
            return false;
        }
    }

private:
    string uniqueDbusName;
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
