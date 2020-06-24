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

module apkd_dbus_server.main;

import apkd_common.gettext;
static import apkd_common.globals;
import apkd_common.SysLogger;
import apkd_dbus_server.DbusServer;
import apkd_dbus_server.Options;
import glib.MainContext;
import glib.MainLoop;
import glib.Timeout;
import std.format : format;
import std.stdio : writefln, writeln;

extern extern (C) __gshared bool rt_trapExceptions;
extern extern (C) int _d_run_main(int, char**, void*);

extern (C) int main(int argc, char** argv)
{
    rt_trapExceptions = false;
    return _d_run_main(argc, argv, &_main);
}

int _main(string[] args)
{
    auto options = Options(args);

    if (options.showHelp)
    {
        writeln(helpText);
    }
    else if (options.showVersion)
    {
        writefln("apkd-dbus-server version: %s", apkd_common.globals.apkdVersion);
    }

    LogLevel logLevel;
    switch (options.debugLevel)
    {
    case 0:
        logLevel = LogLevel.error;
        break;
    case -1:
    case 1:
        logLevel = LogLevel.warning;
        break;
    case 2:
        logLevel = LogLevel.info;
        break;
    case 3:
        logLevel = LogLevel.trace;
        break;
    default:
        throw new Exception(format("Invalid debug level %d! Log levels must be between 0 and 3.",
                options.debugLevel));
    }
    setupLogging(logLevel);

    bindtextdomain("apk-polkit", apkd_common.globals.localeDir);
    textdomain("apk-polkit");

    auto mainContext = MainContext.default_();
    mainContext.pushThreadDefault();
    auto mainLoop = new MainLoop(mainContext, false);
    new DBusServer();
    mainLoop.run();
    return 0;
}
