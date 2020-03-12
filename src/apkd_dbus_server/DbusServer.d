module apkd_dbus_server.DBusServer;

import apkd.ApkDataBase;
import ddbus;
import std.exception;
import std.stdio;

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
        this.db = new ApkDataBase();
    }

    bool updateRepositories()
    {
        return this.db.updateRepositories(false);
    }

private:
    ApkDataBase db;
}
