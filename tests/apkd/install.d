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

int main(string[] args)
{
    auto testHelper = TestHelper(args, "install");

    auto database = new ApkDataBase(testHelper.apkRootDir, testHelper.repoDir);
    if (!database.updateRepositories(true))
    {
        stderr.writeln("Updating repos failed!");
        return 1;
    }

    // FIXME: This is ugly, but right now apk fails to chown files
    // correctly if run as non-root. See https://gitlab.alpinelinux.org/alpine/apk-tools/merge_requests/5
    try
    {
        database.addPackage(["test-a"]);
    }
    catch (ApkDatabaseCommitException)
    {
    }

    auto testA = execute(buildPath(testHelper.apkRootDir, "usr", "bin", "test-a"));

    enforce(testA[1].strip() == "hello from test-a-1.0",
            format("Expected 'hello from test-a-1.0', got '%s'", testA[1].strip()));

    // FIXME: See above
    try
    {
        database.addPackage(["test-e"]);
    }
    catch (ApkDatabaseCommitException)
    {
    }

    auto testB = execute(buildPath(testHelper.apkRootDir, "usr", "bin", "test-b"));

    enforce(testB[1].strip() == "hello from test-b-1.0",
            format("Expected 'hello from test-b-1.0', got '%s'", testB[1].strip()));

    auto testE = execute(buildPath(testHelper.apkRootDir, "usr", "bin", "test-e"));

    enforce(testE[1].strip() == "hello from test-e-1.0",
            format("Expected 'hello from test-e-1.0', got '%s'", testE[1].strip()));

    return 0;
}
