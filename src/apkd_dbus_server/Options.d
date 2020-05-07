/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://gitlab.alpinelinux.org/Cogitri/apk-polkit).

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
  apkd-dbus-server [OPTION...]

APKD Dbus Server


Help Options:
  -h, --help         - Show help options.

Application Options:
  -v, --version      - Print program version.
  -d, --debug [0-3]  - Specify the debug level.";

/// CLI `Options` of `apkd`
struct Options
{
    bool showVersion;
    bool showHelp;
    int debugLevel = -1;

    /**
    * Construct a `Options` from CLI args.
    *
    * Params:
    *   args =   The CLI args passed to the main() of your application.
    *            Be mindful that the arguments picked up by this `Options`
    *            implementation are removed from args.
    */
    this(ref string[] args) @safe
    {
        getopt(args, "help|h", &this.showHelp, "version|v",
                &this.showVersion, "debug|d", &this.debugLevel);
    }

    @safe unittest
    {
        import std.array : array;

        auto args = array(["apkd-dbus-server", "-h"]);
        assert(new Options(args).showHelp);
        assert(args.length == 1);
        args ~= "--version";
        assert(new Options(args).showVersion);
        assert(args.length == 1);
    }
}
