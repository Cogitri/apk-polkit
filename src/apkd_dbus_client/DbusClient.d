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

    void upgrade(string packageName)
    {
        auto msg = this.pathInterface.upgradePackage(packageName);
    }

    void upgradeAll()
    {
        auto msg = this.pathInterface.upgradeAllPackages();
    }

    void deletePackage(string packageName)
    {
        auto msg = this.pathInterface.deletePackage(packageName);
    }

    void addPackage(string packageName)
    {
        auto msg = this.pathInterface.addPackage(packageName);
    }

private:
    Connection connection;
    PathIface pathInterface;
}
