/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://gitlab.alpinelinux.org/Cogitri/apk-polkit).

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

module tests.apkd.install;

import apkd.ApkDataBase;
import apkd.exceptions;
import std.exception;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.string;
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
    auto testHelper = TestHelper(args, "install");

    auto database = new ApkDataBase(testHelper.apkRootDir, testHelper.repoDir);
    if (!database.updateRepositories(true))
    {
        stderr.writeln("Updating repos failed!");
        return 1;
    }

    database.addPackages(["test-a"]);

    auto testA = execute(buildPath(testHelper.apkRootDir, "usr", "bin", "test-a"));

    enforce(testA[1].strip() == "hello from test-a-1.0",
            format("Expected 'hello from test-a-1.0', got '%s'", testA[1].strip()));

    database.addPackages(["test-e"]);

    auto testB = execute(buildPath(testHelper.apkRootDir, "usr", "bin", "test-b"));

    enforce(testB[1].strip() == "hello from test-b-1.0",
            format("Expected 'hello from test-b-1.0', got '%s'", testB[1].strip()));

    auto testE = execute(buildPath(testHelper.apkRootDir, "usr", "bin", "test-e"));

    enforce(testE[1].strip() == "hello from test-e-1.0",
            format("Expected 'hello from test-e-1.0', got '%s'", testE[1].strip()));

    return 0;
}
