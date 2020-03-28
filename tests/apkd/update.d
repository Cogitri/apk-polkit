module tests.apkd.update;

import apkd.ApkDataBase;
import std.exception;
import tests.apkd.testlib;

int main(string[] args)
{
    auto testHelper = TestHelper(args, "update", false);
    auto database = new ApkDataBase(testHelper.apkRootDir, testHelper.repoDir);
    auto updateSuccesful = database.updateRepositories(true);
    enforce(updateSuccesful,
            "Updating the repositories wasn't successful when we expected it to be!");
    // We don't sign the APKINDEX in our tests, so this should fail
    auto updateSucessfulTrusted = database.updateRepositories(false);
    enforce(!updateSucessfulTrusted,
            "Updating the repositories was successful when we expected it to fail due to an invalid APKINDEX signature!");
    return 0;
}
