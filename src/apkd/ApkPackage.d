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

module apkd.ApkPackage;

import std.conv;
import std.datetime : unixTimeToStdTime, SysTime;
import std.format : format;
import std.typecons;
import deimos.apk_toolsd.apk_package;

class ApkPackage
{
    this(string name, string old_package_version, string package_version, string arch, string license,
            string origin, string maintainer, string url, string description, string commit,
            string filename, ulong installedSize, ulong size, SysTime buildTime)
    {
        this.m_name = name;
        this.m_version = package_version;
        this.m_arch = arch;
        this.m_license = license;
        this.m_origin = origin;
        this.m_maintainer = maintainer;
        this.m_url = url;
        this.m_description = description;
        this.m_commit = commit;
        this.m_filename = filename;
        this.m_installedSize = installedSize;
        this.m_size = size;
        this.m_buildTime = buildTime;
        this.m_old_version = package_version;
    }

    this(apk_package apk_package)
    {

        this(to!string(apk_package.name.name),
                to!string(apk_package.version_.ptr), null, to!string(apk_package.arch.ptr),
                to!string(apk_package.license.ptr), to!string(apk_package.origin.ptr),
                to!string(apk_package.maintainer.ptr), to!string(apk_package.url),
                to!string(apk_package.description), to!string(apk_package.commit), to!string(apk_package.filename),
                apk_package.installed_size, apk_package.size,
                SysTime(unixTimeToStdTime(apk_package.build_time)));
    }

    this(apk_package old_package, apk_package new_package)
    {
        this(to!string(new_package.name.name),
                to!string(new_package.version_.ptr), to!string(old_package.version_.ptr),
                to!string(new_package.arch.ptr), to!string(new_package.license.ptr),
                to!string(new_package.origin.ptr), to!string(new_package.maintainer.ptr),
                to!string(new_package.url), to!string(new_package.description), to!string(new_package.commit),
                to!string(new_package.filename), new_package.installed_size,
                new_package.size, SysTime(unixTimeToStdTime(new_package.build_time)));
    }

    override string toString()
    {
        return format("Packagename: %s\n Version %s\n", this.m_name, this.m_version);
    }

private:
    string m_name;
    string m_version;
    string m_old_version;
    string m_arch;
    string m_license;
    string m_origin;
    string m_maintainer;
    string m_url;
    string m_description;
    string m_commit;
    string m_filename;
    ulong m_installedSize;
    ulong m_size;
    SysTime m_buildTime;
}
