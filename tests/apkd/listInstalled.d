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

module tests.apkd.listInstalled;

import apkd.ApkDataBase;
import std.exception;
import std.format;
import tests.apkd.testlib;

int main(string[] args)
{
    auto testHelper = TestHelper(args, "listInstalled");
    auto database = new ApkDataBase(testHelper.apkRootDir, testHelper.repoDir);
    auto installedPkgs = database.getInstalledPackages();
    immutable auto expectedInstalledPkgs = 0;
    enforce(installedPkgs.length == expectedInstalledPkgs,
            format("Expected %s installed packages, got %s",
                expectedInstalledPkgs, installedPkgs.length));
    return 0;
}
