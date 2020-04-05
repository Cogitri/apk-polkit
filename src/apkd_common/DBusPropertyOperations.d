module apkd_common.DBusPropertyOperations;

import apkd_common.CommonOperations;
import std.conv : to;

class DBusPropertyOperations : CommonOperations
{
    enum Enum
    {
        getAll,
        getAllowUntrustedRepos,
        setAllowUntrustedRepos,
    }

    this(Enum val) nothrow
    {
        this.m_val = val;
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
        case getAllowUntrustedRepos:
            action = "getAllowUntrustedRepos";
            break;
        case setAllowUntrustedRepos:
            action = "setAllowUntrustedRepos";
            break;
        }

        return prefix ~ "." ~ action;
    }

    @property Enum val() const
    {
        return this.m_val;
    }

private:
    Enum m_val;
}
