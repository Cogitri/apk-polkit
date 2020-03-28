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
