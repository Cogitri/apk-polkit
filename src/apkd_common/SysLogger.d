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

module apkd_common.SysLogger;

version (CRuntime_Musl)
{
    import apkd_common.muslsyslog;
}
else
{
    import core.sys.posix.syslog;
}

import std.exception;
import std.experimental.logger;
public import std.experimental.logger : LogLevel;
import std.stdio;
import std.string;

/// Exception thrown if there specified loglevel is invalid
class InvalidLogLevelException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(msg, file, line);
    }
}

/// This `Logger` implementation is basically a `FileLogger` but also
/// logs to syslog.
class SyslogLogger : FileLogger
{
    /// Construct a `SyslogLogger` and call `openlog`.
    this(LogLevel lv, File logFile) @trusted
    {
        super(logFile, lv);
        openlog("apkd", LOG_NDELAY, LOG_DAEMON);
    }

    /// Write the log message to both stderr and syslog. Doesn't log if
    /// loglevel is none.
    override void writeLogMsg(ref LogEntry payload) @trusted
    {
        super.writeLogMsg(payload);
        if (this.logLevel != LogLevel.off)
        {
            syslog(toSyslogLevel(payload.logLevel), "%.*s",
                    cast(int) payload.msg.length, payload.msg.ptr);
        }
    }
}

/// Convert an enum to the respective syslog log level.
auto toSyslogLevel(LogLevel lv) @safe
{
    final switch (lv) with (LogLevel)
    {
    case trace:
    case all:
        return LOG_DEBUG;
    case info:
        return LOG_INFO;
    case warning:
        return LOG_WARNING;
    case error:
        return LOG_ERR;
    case critical:
        return LOG_CRIT;
    case fatal:
        return LOG_ALERT;
    case off:
        throw new InvalidLogLevelException(
                "Syslog doesn't support no logging. Please check this beforehand.");
    }
}

/// Setup the logging with the supplied logging level.
void setupLogging(const LogLevel l, File logFile = stderr) @safe
{
    sharedLog = new SyslogLogger(l, logFile);
}

@safe unittest
{
    assert(LOG_DEBUG == toSyslogLevel(LogLevel.trace));
    assert(LOG_DEBUG == toSyslogLevel(LogLevel.all));
    assert(LOG_INFO == toSyslogLevel(LogLevel.info));
    assert(LOG_WARNING == toSyslogLevel(LogLevel.warning));
    assert(LOG_ERR == toSyslogLevel(LogLevel.error));
    assert(LOG_CRIT == toSyslogLevel(LogLevel.critical));
    assert(LOG_ALERT == toSyslogLevel(LogLevel.fatal));
}

@safe unittest
{
    import std.algorithm : count;
    import std.file : readText, remove;

    const auto testLogPath = deleteme();
    scope (exit)
        remove(testLogPath);

    setupLogging(LogLevel.info, File(testLogPath, "w"));
    trace("trace");
    error("error");
    immutable auto expectedVal = 1;
    const auto logFileNumLines = readText(testLogPath).count('\n');
    assert(expectedVal == logFileNumLines, format("Expected %d, got %d",
            expectedVal, logFileNumLines));
}

@safe unittest
{
    assertThrown!InvalidLogLevelException(toSyslogLevel(LogLevel.off));
}
