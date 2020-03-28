module tests.apkd.listAvailable;

import apkd.ApkDataBase;
import std.exception;
import std.format;
import tests.apkd.testlib;

int main(string[] args)
{
    auto testHelper = TestHelper(args, "listAvailable");
    auto database = new ApkDataBase(testHelper.apkRootDir, testHelper.repoDir);
    auto availablePkgs = database.getAvailablePackages();
    immutable auto expectedAvailablePkgs = 5;
    enforce(availablePkgs.length == expectedAvailablePkgs,
            format("Expected %s available packages, got %s",
                expectedAvailablePkgs, availablePkgs.length));
    return 0;
}
