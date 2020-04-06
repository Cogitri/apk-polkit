# Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>
#
# This file is part of apk-polkit (see https://github.com/Cogitri/apk-polkit).
#
# apk-polkit is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# apk-polkit is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with apk-polkit. If not, see <https://www.gnu.org/licenses/>.


"""
Mock template for apkd_dbus_server
"""

__author__ = "Rasmus Thomsen <oss@cogitri.dev>"
__email__ = "oss@cogitri.dev"
__copyright__ = "Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>"
__license__ = "GPL-3.0-or-later"


import dbus
from dbusmock import MOCK_IFACE, mockobject

BUS_NAME = "dev.Cogitri.apkPolkit.Helper"
MAIN_OBJ = "/dev/Cogitri/apkPolkit/Helper"
MAIN_IFACE = "dev.Cogitri.apkPolkit.Helper"
SYSTEM_BUS = True


def load(mock, parameters):
    mock.AddMethods(
        MAIN_IFACE,
        [
            ("updateRepositories", "", "", ""),
            ("upgradePackage", "as", "", ""),
            ("upgradeAllPackages", "", "", ""),
            ("deletePackage", "as", "", ""),
            ("addPackage", "as", "", ""),
        ],
    )

    mock.AddProperties(
        MAIN_IFACE, dbus.Dictionary({"allowUntrustedRepos": dbus.Boolean(False)})
    )


@dbus.service.method(MAIN_IFACE, in_signature="", out_signature="a(ssssssssssstt)")
def listAvailablePackages(self):
    returnList = []
    returnList.append(
        (
            dbus.String("test-a"),
            dbus.String("1.0"),
            dbus.String("0.9"),
            dbus.String("all"),
            dbus.String("GPL-3.0-or-later"),
            dbus.String("Cogitri"),
            dbus.String("Rasmus Thomsen <oss@cogitri.dev>"),
            dbus.String("https://gitlab.alpinelinux.org/Cogitri/apk-polkit"),
            dbus.String("description"),
            dbus.String("abcdef"),
            dbus.String("test-a-1.0.apk"),
            dbus.UInt64(513),
            dbus.UInt64(337),
        ),
    )
    return returnList


@dbus.service.method(MAIN_IFACE, in_signature="", out_signature="a(ssssssssssstt)")
def listInstalledPackages(self):
    returnList = []
    returnList.append(
        (
            dbus.String("test-a"),
            dbus.String("1.0"),
            dbus.String("0.9"),
            dbus.String("all"),
            dbus.String("GPL-3.0-or-later"),
            dbus.String("Cogitri"),
            dbus.String("Rasmus Thomsen <oss@cogitri.dev>"),
            dbus.String("https://gitlab.alpinelinux.org/Cogitri/apk-polkit"),
            dbus.String("description"),
            dbus.String("abcdef"),
            dbus.String("test-a-1.0.apk"),
            dbus.UInt64(513),
            dbus.UInt64(337),
        ),
    )
    return returnList


@dbus.service.method(MAIN_IFACE, in_signature="", out_signature="a(ssssssssssstt)")
def listUpgradablePackages(self):
    returnList = []
    returnList.append(
        (
            dbus.String("test-a"),
            dbus.String("1.0"),
            dbus.String("0.9"),
            dbus.String("all"),
            dbus.String("GPL-3.0-or-later"),
            dbus.String("Cogitri"),
            dbus.String("Rasmus Thomsen <oss@cogitri.dev>"),
            dbus.String("https://gitlab.alpinelinux.org/Cogitri/apk-polkit"),
            dbus.String("description"),
            dbus.String("abcdef"),
            dbus.String("test-a-1.0.apk"),
            dbus.UInt64(513),
            dbus.UInt64(337),
        ),
    )
    return returnList
