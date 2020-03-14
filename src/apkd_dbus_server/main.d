module apkd_dbus_server.main;

import apkd.SysLogger;
import ddbus;
import ddbus.c_lib : DBusBusType;
import apkd_dbus_server.DbusServer;

int main()
{
    setupLogging(LogLevel.warning);
    auto dbusConnection = connectToBus(DBusBusType.DBUS_BUS_SYSTEM);
    auto dbusServer = new DBusServer(dbusConnection);
    simpleMainLoop(dbusConnection);
    return 0;
}
