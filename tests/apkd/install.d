module tests.apkd.install;

import apkd.ApkDataBase;
import apkd.exceptions;
import deimos.apk_toolsd.apk_defines;
import std.exception;
import std.file;
import std.format;
import std.process;
import std.stdio;

int main(string[] args)
{
    auto apkRootDir = format("%s-%s", args[1], "install");
    auto repoDir = format("%s-%s", args[2], "install/repo");
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
        return 0;
    }

    return 0;
}
