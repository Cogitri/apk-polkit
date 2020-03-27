module tests.apkd.install;

import apkd.ApkDataBase;
import apkd.exceptions;
import std.stdio;
import tests.apkd.testlib;

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
        return 0;
    }

    return 0;
}
