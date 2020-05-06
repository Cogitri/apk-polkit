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

module tests.apkd.update;

import apkd.ApkDataBase;
import deimos.apk_toolsd.apk_defines;
import std.exception;
import tests.apkd_test_common.testlib;

extern extern (C) __gshared bool rt_trapExceptions;
extern extern (C) int _d_run_main(int, char**, void*);

extern (C) int main(int argc, char** argv)
{
    rt_trapExceptions = false;
    return _d_run_main(argc, argv, &_main);
}

int _main(string[] args)
{
    auto testHelper = TestHelper(args, "update", false);
    auto database = new ApkDataBase(testHelper.apkRootDir, testHelper.repoDir);
    apk_flags = 0;
    auto updateSuccesful = database.updateRepositories(true);
    enforce(updateSuccesful,
            "Updating the repositories wasn't successful when we expected it to be!");
    // We don't sign the APKINDEX in our tests, so this should fail
    auto updateSucessfulUntrusted = database.updateRepositories(false);
    enforce(!updateSucessfulUntrusted,
            "Updating the repositories was successful when we expected it to fail due to an invalid APKINDEX signature!");
    return 0;
}
