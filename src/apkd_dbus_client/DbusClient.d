module libapkd_dbus_client.DbusClient;

import ddbus;
import ddbus.c_lib : DBusBusType;

class DBusClient
{
    this()
    {
        this.connection = connectToBus(DBusBusType.DBUS_BUS_SYSTEM);
        this.pathInterface = new PathIface(this.connection, "dev.Cogitri.apkPolkit.Helper",
                "/dev/Cogitri/apkPolkit/Helper", "dev.Cogitri.apkPolkit.Helper");
    }

    void update()
    {
        auto msg = this.pathInterface.updateRepositories();
    }

private:
    Connection connection;
    PathIface pathInterface;
}
