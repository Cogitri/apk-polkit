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
    enforce(availablePkgs.length == 4, format("%s", availablePkgs.length));
    return 0;
}
