module tests.apkd.listAvailable;

import apkd.ApkDataBase;
import apkd.exceptions;
import deimos.apk_toolsd.apk_defines;
import std.exception;
import std.file;
import std.format;
import std.process;

int main(string[] args)
{
    auto apkRootDir = format("%s-%s", args[1], "listAvailable");
    auto repoDir = format("%s-%s", args[2], "listAvailable/repo");
    apk_flags = APK_ALLOW_UNTRUSTED;
    apk_verbosity = 2;

    scope (exit)
    {
        execute(["rm", "-rf", apkRootDir]);
        execute(["rm", "-rf", repoDir]);
    }

    auto runScript = execute([args[3], apkRootDir, repoDir]);
    enforce(runScript[0] == 0, runScript[1]);

    auto database = new ApkDataBase(apkRootDir, repoDir);
    auto availablePkgs = database.getAvailablePackages();
    enforce(availablePkgs.length == 4, format("%s", availablePkgs.length));
    return 0;
}
