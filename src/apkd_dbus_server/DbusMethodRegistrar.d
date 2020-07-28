module apkd_dbus_server.DbusMethodRegistrar;

import apkd_common.gettext : gettext;
import glib.Variant : Variant;
import std.format : format;

alias DbusRetParamValMethod = Variant delegate(Variant parameters);
alias DbusRetValMethod = Variant delegate();
alias DbusParamValMethod = void delegate(Variant parameters);
alias DbusNoRetParamValMethod = void delegate();

class DbusMethodNotFoundException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(msg, file, line);
    }
}

class DbusMethodRegistrar
{
    public static DbusMethodRegistrar getInstance()
    {
        if (!this.instance)
        {
            this.instance = new DbusMethodRegistrar();
        }
        return this.instance;
    }

    public void register(DbusRetParamValMethod method, string name)
    {
        this.full_methods[name] = method;
    }

    public void register(DbusRetValMethod method, string name)
    {
        this.ret_methods[name] = method;
    }

    public void register(DbusParamValMethod method, string name)
    {
        this.param_methods[name] = method;
    }

    public void register(DbusNoRetParamValMethod method, string name)
    {
        this.void_methods[name] = method;
    }

    public Variant call(string methodName, Variant parameters)
    {
        if (auto val = methodName in this.full_methods)
        {
            return (*val)(parameters);
        }
        else if (auto val = methodName in this.param_methods)
        {
            (*val)(parameters);
            return null;
        }
        else if (auto val = methodName in this.ret_methods)
        {
            return (*val)();
        }
        else if (auto val = methodName in this.void_methods)
        {
            (*val)();
            return null;
        }
        else
        {
            throw new DbusMethodNotFoundException(format(gettext("Unknown DBus method %s"),
                    methodName));
        }
    }

    private this()
    {
    }

    private static DbusMethodRegistrar instance;
    private DbusRetParamValMethod[string] full_methods;
    private DbusParamValMethod[string] param_methods;
    private DbusRetValMethod[string] ret_methods;
    private DbusNoRetParamValMethod[string] void_methods;
}
