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

import deimos.apk_toolsd.apk_package;
import std.conv : to;
import std.datetime : unixTimeToStdTime, SysTime;
import std.format : format;

struct ApkPackage
{
    this(string name, string packageVersion, string oldPackageVersion, string arch, string license,
            string origin, string maintainer, string url, string description, string commit,
            string filename, ulong installedSize, ulong size, SysTime buildTime)
    {
        this.m_name = name;
        this.m_version = packageVersion;
        this.m_oldVersion = oldPackageVersion;
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
    }

    this(apk_package apk_package)
    in
    {
        assert(apk_package.name.name);
        assert(apk_package.version_.ptr);
        assert(apk_package.arch.ptr);
        assert(apk_package.license.ptr);
        assert(apk_package.origin.ptr);
        apk_package.maintainer ? assert(apk_package.maintainer.ptr) : true;
        assert(apk_package.url);
        assert(apk_package.description);
        assert(apk_package.commit);
        assert(apk_package.size);
        assert(apk_package.build_time);
    }
    do
    {
        // dfmt off
        this(
            to!string(apk_package.name.name),
            apk_package.version_.ptr[0 .. apk_package.version_.len].to!string,
            null,
            apk_package.arch.ptr[0 .. apk_package.arch.len].to!string,
            apk_package.license.ptr[0 .. apk_package.license.len].to!string,
            apk_package.origin.ptr[0 .. apk_package.origin.len].to!string,
            apk_package.maintainer ? apk_package.maintainer.ptr[0 .. apk_package.maintainer.len].to!string: null,
            to!string(apk_package.url),
            to!string(apk_package.description),
            to!string(apk_package.commit),
            apk_package.filename ? apk_package.filename.to!string() : null, apk_package.installed_size,
            apk_package.size,
            SysTime(unixTimeToStdTime(apk_package.build_time)),
        );
        // dfmt on
    }

    this(apk_package old_package, apk_package new_package)
    in
    {
        assert(old_package.version_.ptr);
    }
    do
    {
        this(new_package);
        this.m_oldVersion = old_package.version_.ptr[0 .. old_package.version_.len].to!string;
    }

    string toString()
    {
        return format("Packagename: %s\n Version %s\n", this.m_name, this.m_version);
    }

    @property string name() const
    {
        return m_name;
    }

    @property newVersion() const
    {
        return m_version;
    }

    @property string oldVersion() const
    {
        return m_oldVersion;
    }

    @property string arch() const
    {
        return m_arch;
    }

    @property string license() const
    {
        return m_license;
    }

    @property string origin() const
    {
        return m_origin;
    }

    @property string maintainer() const
    {
        return m_maintainer;
    }

    @property string url() const
    {
        return m_url;
    }

    @property string description() const
    {
        return m_description;
    }

    @property string commit() const
    {
        return m_commit;
    }

    @property string filename() const
    {
        return m_filename;
    }

    @property ulong installedSize() const
    {
        return m_installedSize;
    }

    @property ulong size() const
    {
        return m_size;
    }

    @property SysTime buildTime() const
    {
        return m_buildTime;
    }

private:
    string m_name;
    string m_version;
    string m_oldVersion;
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
