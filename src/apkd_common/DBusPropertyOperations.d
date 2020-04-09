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

module apkd_common.DBusPropertyOperations;

import apkd_common.CommonOperations;
import std.conv : to;

class DBusPropertyOperations : CommonOperations
{
    enum Enum
    {
        getAll,
        allowUntrustedRepos,
        root,
    }

    enum DirectionEnum
    {
        get,
        set,
    }

    this(Enum val, DirectionEnum direction) nothrow
    {
        this.m_val = val;
        this.m_direction = direction;
    }

    this(string methodName)
    {
        this.m_val = methodName.to!Enum;
    }

    override string toString() const
    {
        return this.val.to!string;
    }

    override string toPolkitAction() const
    {
        immutable auto prefix = "dev.Cogitri.apkPolkit.Helper";

        string action;

        final switch (this.val) with (Enum)
        {
        case getAll:
            action = "getAllProperties";
            break;
        case allowUntrustedRepos:
            action = this.direction.to!string ~ "AllowUntrustedRepos";
            break;
        case root:
            action = this.direction.to!string ~ "Root";
            break;
        }

        return prefix ~ "." ~ action;
    }

    @property Enum val() const
    {
        return this.m_val;
    }

    @property DirectionEnum direction() const
    {
        return this.m_direction;
    }

private:
    DirectionEnum m_direction;
    Enum m_val;
}
