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
