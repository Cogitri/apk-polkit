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

module tests.apkd.listUpgradable;

import apkd.ApkDataBase;
import apkd.exceptions;
import std.exception;
import std.format;
import tests.apkd_test_common.testlib;

int main(string[] args)
{
    auto testHelper = TestHelper(args, "listUpgradeable");
    auto database = new ApkDataBase(testHelper.apkRootDir, testHelper.repoDir);
    auto upgradeablePkgsEmptyInstall = database.getUpgradablePackages();
    immutable auto expectedUpgradeablePkgsEmptyInstall = 0;
    enforce(upgradeablePkgsEmptyInstall.length == expectedUpgradeablePkgsEmptyInstall,
            format("Expected %s upgradable packages, got %s",
                expectedUpgradeablePkgsEmptyInstall, upgradeablePkgsEmptyInstall.length));
    // FIXME: see install.d
    try
    {
        database.addPackage(["test-a", "test-b", "test-e"]);
    }
    catch (ApkDatabaseCommitException)
    {
    }
    auto upgradeablePkgs = database.getUpgradablePackages();
    return 0;
}
