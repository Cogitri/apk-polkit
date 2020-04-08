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

module tests.apkd_dbus_client.queryAsync;

import apkd.ApkPackage;
import apkd_common.ApkDataBaseOperations;
import apkd_dbus_client.DbusClient;
import glib.Variant;
import std.datetime : SysTime;
import std.exception : assertThrown;

int main()
{
    auto dbusClient = DBusClient.get();
    auto parentVariant = dbusClient.querySync([],
            new ApkDataBaseOperations(ApkDataBaseOperations.Enum.listAvailablePackages), null);

    auto packageVariant = parentVariant.getChildValue(0).getChildValue(0);

    ulong len;
    // dfmt off
    auto pkg = ApkPackage(
            packageVariant.getChildValue(0).getString(len),
            packageVariant.getChildValue(1).getString(len),
            packageVariant.getChildValue(2).getString(len),
            packageVariant.getChildValue(3).getString(len),
            packageVariant.getChildValue(4).getString(len),
            packageVariant.getChildValue(5).getString(len),
            packageVariant.getChildValue(6).getString(len),
            packageVariant.getChildValue(7).getString(len),
            packageVariant.getChildValue(8).getString(len),
            packageVariant.getChildValue(9).getString(len),
            packageVariant.getChildValue(10).getString(len),
            packageVariant.getChildValue(11).getUint64(),
            packageVariant.getChildValue(12).getUint64(),
            SysTime(0), //FIXME
        );
    // dfmt on

    assert(pkg.name == "test-a");
    assert(pkg.newVersion == "1.0");
    assert(pkg.oldVersion == "0.9");
    assert(pkg.arch == "all");
    assert(pkg.license == "GPL-3.0-or-later");
    assert(pkg.origin == "Cogitri");
    assert(pkg.maintainer == "Rasmus Thomsen <oss@cogitri.dev>");
    assert(pkg.url == "https://gitlab.alpinelinux.org/Cogitri/apk-polkit");
    assert(pkg.description == "description");
    assert(pkg.commit == "abcdef");
    assert(pkg.installedSize == 513);
    assert(pkg.size == 337);

    return 0;
}
