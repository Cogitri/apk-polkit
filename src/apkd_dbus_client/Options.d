/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://github.com/Cogitri/apk-polkit).

    apk-polkit is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    apk-polkit is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with apk-polkit.  If not, see <https://www.gnu.org/licenses/>.
*/

module apkd_dbus_client.Options;

import std.algorithm.mutation : remove;

import std.conv;
import std.exception;
import std.format;
import std.getopt;
import std.stdio;
import std.typecons : tuple;

immutable helpText = "
Usage:
  apkd <subcommand> [OPTION...]

Interact with APK

Subcommands:
  add [PKGNAME(S)]     - Add the package(s) identified by PKGNAME
  del[PKGNAME(S)]      - Remove the package(s) identified by PKGNAME and its dependencies
  list [--installed|-i]- List packages available. Pass -i for installed packages.
  update               - Update all repositories
  upgrade              - Upgrade all packages
  upgrade [PKGNAME(S)] - Upgrade the package(s) identified by PKGNAME

Help Options:
  -h, --help         - Show help options.

Application Options:
  -v, --version      - Print program version.
  -d, --debug [0-3]  - Specify the debug level.";

class InsufficientArgLengthException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(msg, file, line);
    }
}

class UnexpectedArgumentException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(msg, file, line);
    }
}

class UnknownArgumentException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(msg, file, line);
    }
}

/// CLI `Options` of `apkd`
struct Options
{
    bool showVersion;
    bool showHelp;
    bool installed;
    int debugLevel = -1;
    string mode;
    string[] packageNames;

    this(ref string[] args) @safe
    {
        getopt(args, "help|h", &this.showHelp, "version|v", &this.showVersion,
                "debug|d", &this.debugLevel, "installed|i", &this.installed);

        if (showHelp || showVersion)
        {
            return;
        }

        enforce!InsufficientArgLengthException(args.length >= 2, "Please specify a subcommand.");

        this.mode = args[1];
        switch (this.mode)
        {
        case "list":
        case "update":
            enforce!UnexpectedArgumentException(args.length == 2,
                    format("Didn't expect the additional arguments %s to subcommand '%s'",
                        args.remove(tuple(0, 2)), this.mode));
            break;
        case "add":
        case "del":
            enforce!InsufficientArgLengthException(args.length >= 3,

                    format("Expected a package name supplied to subcommand %s", this.mode));
            goto case "upgrade";
        case "upgrade":
            for (auto i = 2; i < args.length; i++)
            {
                this.packageNames ~= args[i];
            }
            break;
        default:
            throw new UnknownArgumentException(format("Unknown subcommand %s", this.mode));
        }
    }
}

@safe unittest
{
    import std.array : array;
    import std.stdio;

    auto args = array(["apkd", "-h"]);
    assert(new Options(args).showHelp);
    assert(args.length == 1);
    args ~= "--version";
    assert(new Options(args).showVersion);
    assert(args.length == 1);

    assertThrown!InsufficientArgLengthException(new Options(args));

    args ~= "update";
    assert(new Options(args).mode == "update");
    args ~= "unexpectedarg";
    assertThrown!UnexpectedArgumentException(new Options(args));

    args = array(["apkd", "upgrade"]);
    auto optionsUpgrade = new Options(args);
    assert(optionsUpgrade.mode == "upgrade");
    args ~= "package";
    optionsUpgrade = new Options(args);
    assert(optionsUpgrade.packageNames == ["package"]);

    args = array(["apkd", "add"]);
    assertThrown!InsufficientArgLengthException(new Options(args));
    args ~= "package";
    auto optionsAdd = new Options(args);
    assert(optionsAdd.mode == "add");
    assert(optionsAdd.packageNames == ["package"]);

    args = array(["apkd", "del"]);
    assertThrown!InsufficientArgLengthException(new Options(args));
    args ~= "package";
    auto optionsDel = new Options(args);
    assert(optionsDel.mode == "del");
    assert(optionsDel.packageNames == ["package"]);

    args = array(["apkd", "unknownarg"]);
    assertThrown!UnknownArgumentException(new Options(args));
}
