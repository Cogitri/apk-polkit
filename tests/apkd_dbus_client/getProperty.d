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

module tests.apkd_dbus_client.getProperty;

import apkd_common.DBusPropertyOperations;
import apkd_dbus_client.DbusClient;
import glib.Variant;
import std.exception : assertThrown;

int main()
{
    auto dbusClient = DBusClient.get();
    dbusClient.getProperty(new DBusPropertyOperations(DBusPropertyOperations.Enum.allowUntrustedRepos,
            DBusPropertyOperations.DirectionEnum.get), null);
    return 0;
}
