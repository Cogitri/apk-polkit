module apkd_common.ApkDatabaseOperations;

import std.conv;

class ApkDataBaseOperations
{
    enum Enum
    {
        addPackage,
        deletePackage,
        listInstalledPackages,
        listAvailablePackages,
        updateRepositories,
        upgradeAllPackages,
        upgradePackage,
    }

    this(Enum val)
    {
        this.m_val = val;
    }

    this(string methodName)
    {
        this.m_val = methodName.to!Enum;
    }

    override string toString()
    {
        return this.val.to!string;
    }

    string toPolkitAction()
    {
        immutable auto prefix = "dev.Cogitri.apkPolkit.Helper";

        string action;

        final switch (this.val) with (Enum)
        {
        case addPackage:
            action = "add";
            break;
        case deletePackage:
            action = "delete";
            break;
        case listInstalledPackages:
            action = "listInstalled";
            break;
        case listAvailablePackages:
            action = "listAvailable";
            break;
        case updateRepositories:
            action = "update";
            break;
        case upgradeAllPackages:
        case upgradePackage:
            action = "upgrade";
            break;
        }

        return prefix ~ "." ~ action;
    }

    @property Enum val()
    {
        return this.m_val;
    }

private:
    Enum m_val;
}
