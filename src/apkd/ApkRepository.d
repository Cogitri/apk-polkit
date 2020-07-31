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

module apkd.ApkRepository;

import deimos.apk_toolsd.apk_database;
import std.conv : to;
import std.format : format;

/// Struct containing all the information about a repository
struct ApkRepository
{

    this(string description, string url, bool enabled = true)
    {
        this.m_description = description;
        this.m_enabled = enabled;
        this.m_url = url;
    }

    this(string url, bool enabled)
    {
        this("", url, enabled);
    }

    @property bool enabled() const
    {
        return this.m_enabled;
    }

    @property string description() const
    {
        return this.m_description;
    }

    @property string url() const
    {
        return this.m_url;
    }

private:
    bool m_enabled;
    string m_description;
    string m_url;
}
