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

module tests.apkd.testlib;

import deimos.apk_toolsd.apk_defines;
import std.exception;
import std.format;
import std.path : buildPath;
import std.process;

struct TestHelper
{
    @disable this();

    this(string[] args, string testAppletName, bool allowUntrusted = true)
    {
        this.apkRootDir = format("%s-%s", args[1], testAppletName);
        auto abuildBuildDir = format("%s-%s", args[2], testAppletName);
        this.repoDir = buildPath(abuildBuildDir, "abuilds");
        if (allowUntrusted)
        {
            apk_flags = APK_ALLOW_UNTRUSTED;
        }
        apk_verbosity = 2;

        auto runScript = execute([args[3], this.apkRootDir, abuildBuildDir]);
        enforce(runScript[0] == 0, runScript[1]);
    }

    ~this()
    {
        execute(["rm", "-rf", this.apkRootDir]);
        execute(["rm", "-rf", this.repoDir]);
    }

    string apkRootDir;
    string repoDir;
}
