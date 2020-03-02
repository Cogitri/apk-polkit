module tests.ApkFrontend;

import std.stdio : writeln;
import apkd.ApkDataBase;

int main(string[] args)
{
    const auto op = args[1];

    auto database = new ApkDataBase();

    switch (op)
    {
    case "update":
        assert(database.updateRepositories(false));
        break;
    case "list":
        auto res = database.getUpgradablePackages();
        writeln(res);
        break;
    default:
        assert(0);
    }

    return 0;
}
