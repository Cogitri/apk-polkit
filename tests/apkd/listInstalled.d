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
    enforce(installedPkgs.length == 0, format("%s", installedPkgs.length));
    return 0;
}
