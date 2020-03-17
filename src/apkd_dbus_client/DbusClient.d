module libapkd_dbus_client.DbusClient;

static import apkd_common.globals;
import core.stdc.stdlib : exit;
import gio.c.types : BusType, BusNameWatcherFlags, DBusCallFlags, G_MAXINT32;
import gio.DBusNames;
import gio.DBusConnection;
import glib.Variant;
import glib.VariantType;
import std.exception;
import std.stdio : writeln;

struct DBusClientUserData
{
    string[] packageNames;
    string methodName;
}

class DBusClient
{
    this(string[] packageNames, string methodName)
    {
        this.data = DBusClientUserData(packageNames, methodName);
        this.watcherId = DBusNames.watchName(BusType.SYSTEM, apkd_common.globals.dbusBusName,
                BusNameWatcherFlags.AUTO_START, &onNameAppeared,
                &onNameDisappeared, &this.data, null);
    }

    extern (C) static void onNameAppeared(GDBusConnection* rawConnection,
            const char* name, const char* nameOwner, void* data)
    {
        auto dbusConnection = new DBusConnection(rawConnection);
        auto userData = cast(DBusClientUserData*) data;
        enforce(userData !is null);

        auto success = true;

        if (userData.methodName == "updateRepositories")
        {
            auto res = dbusConnection.callSync(apkd_common.globals.dbusBusName, apkd_common.globals.dbusObjectPath,
                    apkd_common.globals.dbusInterfaceName, userData.methodName, null,
                    new VariantType("(b)"), DBusCallFlags.NONE, G_MAXINT32, null);
            success = success && res.getChildValue(0).getBoolean();
        }
        else
        {
            foreach (packageName; userData.packageNames)
            {
                auto parameters = new Variant(packageName);
                auto res = dbusConnection.callSync(apkd_common.globals.dbusBusName, apkd_common.globals.dbusObjectPath,
                        apkd_common.globals.dbusInterfaceName, userData.methodName,
                        parameters, new VariantType("b"), DBusCallFlags.NONE, 1000, null);
                success = success && res.getChildValue(0).getBoolean();
            }
        }

        if (success)
        {
            exit(0);
        }
        else
        {
            exit(1);
        }
    }

    extern (C) static void onNameDisappeared(GDBusConnection* connection, const char* name, void*)
    {
    }

private:
    uint watcherId;
    DBusClientUserData data;
}
