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

module apkd.ApkPackage;

import deimos.apk_toolsd.apk_package;
import std.conv : to;
import std.datetime : unixTimeToStdTime, SysTime;
import std.format : format;

/// Struct containing all the information about a package
struct ApkPackage
{

    /**
    * Initialize a ApkPackage with a pointer to an apk_package. Keep in mind that the lifetime
    * of the underlying apk_package usually only is for as long as the apk_database it stems from.
    */
    this(apk_package* apkPackage, bool isInstalled = false)
    in
    {
        assert(apkPackage !is null, "apkPackage must not be null!");
        assert(apkPackage.name.name,
                "apkPackage.name is null when we didn't expect it to! This is a bug.");
        assert(apkPackage.version_.ptr,
                "apkPackage.version is null when we didn't expect it to! This is a bug.");
    }
    do
    {
        this.m_apkPackage = apkPackage;
        this.m_isInstalled = isInstalled;
    }

    /**
    * Initialize a ApkPackage with a pointer to an apk_package. Keep in mind that the lifetime
    * of the underlying apk_package usually only is for as long as the apk_database it stems from.
    */
    this(apk_package* oldPackage, apk_package* newPackage)
    in
    {
        assert(oldPackage !is null, "oldPackage must not be null!");
        assert(newPackage !is null, "newPackage must not be null!");
        assert(oldPackage.version_.ptr !is null,
                "oldPackage.version is null when we didn't expect it to! This is a bug.");
    }
    do
    {
        this(newPackage, true);
        this.m_oldVersion = oldPackage.version_.ptr[0 .. oldPackage.version_.len].to!string;
    }

    string toString() const
    {
        return format("Packagename: %s\n Version %s\n", this.name, this.newVersion);
    }

    @property string name() const
    {
        return this.m_apkPackage.name ? this.m_apkPackage.name.name.to!string : null;
    }

    @property string newVersion() const
    {
        return this.m_apkPackage.version_
            ? this.m_apkPackage.version_.ptr[0 .. this.m_apkPackage.version_.len].to!string : null;
    }

    @property string oldVersion() const
    {
        return m_oldVersion;
    }

    @property string arch() const
    {
        return this.m_apkPackage.arch
            ? this.m_apkPackage.arch.ptr[0 .. this.m_apkPackage.arch.len].to!string : null;
    }

    @property string license() const
    {
        return this.m_apkPackage.license
            ? this.m_apkPackage.license.ptr[0 .. this.m_apkPackage.license.len].to!string : null;
    }

    @property string origin() const
    {
        return this.m_apkPackage.origin
            ? this.m_apkPackage.origin.ptr[0 .. this.m_apkPackage.origin.len].to!string : null;
    }

    @property string maintainer() const
    {
        return this.m_apkPackage.maintainer
            ? this.m_apkPackage.maintainer.ptr[0 .. this.m_apkPackage.maintainer.len].to!string
            : null;
    }

    @property string url() const
    {
        return this.m_apkPackage.url ? this.m_apkPackage.url.to!string : null;
    }

    @property string description() const
    {
        return this.m_apkPackage.description ? this.m_apkPackage.description.to!string : null;
    }

    @property string commit() const
    {
        return this.m_apkPackage.commit ? this.m_apkPackage.commit.to!string : null;
    }

    @property string filename() const
    {
        return this.m_apkPackage.filename ? this.m_apkPackage.filename.to!string : null;
    }

    @property ulong installedSize() const
    {
        return this.m_apkPackage.installed_size;
    }

    @property ulong size() const
    {
        return this.m_apkPackage.size;
    }

    @property SysTime buildTime() const
    {
        return SysTime(unixTimeToStdTime(this.m_apkPackage.build_time));
    }

    @property bool isInstalled() const
    {
        return m_isInstalled;
    }

private:
    apk_package* m_apkPackage;
    bool m_isInstalled;
    string m_oldVersion;
}
