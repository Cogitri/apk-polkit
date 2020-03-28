/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://github.com/Cogitri/apk-polkit).

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

module apkd_common.ApkDatabaseOperations;

import std.conv : to;

// Helper struct that aids in translating from a db operation (function)
// one wants to run to the dbus method or the polkit action.
struct ApkDataBaseOperations
{
    enum Enum
    {
        addPackage,
        deletePackage,
        listInstalledPackages,
        listAvailablePackages,
        listUpgradablePackages,
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

    string toString() const
    {
        return this.val.to!string;
    }

    string toPolkitAction() const
    {
        immutable auto prefix = "dev.Cogitri.apkPolkit.Helper";

        string action;

        final switch (this.val) with (Enum)
        {
        case addPackage:
            action = "install";
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
        case listUpgradablePackages:
            action = "listUpgradable";
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

    @property Enum val() const
    {
        return this.m_val;
    }

private:
    Enum m_val;
}
