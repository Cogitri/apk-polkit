module tests.apkd.testlib;

import deimos.apk_toolsd.apk_defines;
import std.exception;
import std.format;
import std.process;

struct TestHelper
{
    @disable this();

    this(string[] args, string testAppletName)
    {
        this.apkRootDir = format("%s-%s", args[1], testAppletName);
        this.repoDir = format("%s-%s/repo", args[2], testAppletName);
        apk_flags = APK_ALLOW_UNTRUSTED;
        apk_verbosity = 2;

        auto runScript = execute([args[3], this.apkRootDir, this.repoDir]);
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
