module apkd_dbus_server.DBusServer;

import apkd.ApkDataBase;
import ddbus;
import std.exception;
import std.stdio;
import std.typecons;

class DBusServer
{
    this(Connection conn)
    {
        auto msgRouter = new MessageRouter();
        auto objectPath = ObjectPath("/dev/Cogitri/apkPolkit/Helper");
        auto interfaceName = interfaceName("dev.Cogitri.apkPolkit.Helper");
        auto busName = busName("dev.Cogitri.apkPolkit.Helper");
        auto msgPattern = MessagePattern(objectPath, interfaceName, "update");
        msgRouter.setHandler!(void)(msgPattern, () { writeln("update"); });
        auto apkInterfacer = new ApkInterfacer();
        registerMethods(msgRouter, objectPath, interfaceName, apkInterfacer);
        registerRouter(conn, msgRouter);
        enforce(requestName(conn, busName));
    }
}

class ApkInterfacer
{
    this()
    {
        this.db = null;
    }

    bool updateRepositories()
    {
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        return dbGuard.db.updateRepositories(false);
    }

    bool upgradePackage(string pkgname)
    {
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.upgradePackage(pkgname);
            return true;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    bool upgradeAllPackages()
    {
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.upgradeAllPackages();
            return true;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    bool deletePackage(string pkgname)
    {
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.deletePackage(pkgname);
            return true;
        }
        catch (Exception e)
        {
            return false;
        }
    }

    bool addPackage(string pkgname)
    {
        auto dbGuard = DatabaseGuard(new ApkDataBase());
        try
        {
            dbGuard.db.addPackage(pkgname);
            return true;
        }
        catch (Exception e)
        {
            return false;
        }
    }

private:
    Nullable!ApkDataBase db;
}

struct DatabaseGuard
{
    @property ref ApkDataBase db()
    {
        return this.m_db;
    }

private:
    ApkDataBase m_db;
}
