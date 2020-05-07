module apkd_dbus_server.Util;

import gio.DBusMethodInvocation;
import glib.Variant;
import std.format : format;
import std.traits : Parameters;

template Call(alias symbol)
{
    template GetVariableForType(T)
    {
        static if (is(T == Variant))
            enum GetVariableForType = "parametersVariant";
        else
            static assert(0, "Type " ~ T.stringof ~ " not supported!");
    }

    template ParameterWrapper(T...)
    {
        static if (T.length == 0)
            enum ParameterWrapper = "";
        else static if (T.length == 1)
            enum ParameterWrapper = GetVariableForType!(T[0]);
        else
            enum ParameterWrapper = GetVariableForType!(T[0]) ~ ", " ~ ParameterWrapper!(T[1 .. $]);
    }

    enum Call = __traits(identifier, symbol) ~ "(" ~ ParameterWrapper!(Parameters!symbol) ~ ");";
}
