module apkd_common.gettext;

import core.stdc.config;
import std.conv : to;
import std.string : toStringz;

extern (C) char* gettext(const char*);
extern (C) char* dgettext(const char*, const char*);
extern (C) char* dcgettext(const char*, const char*, int);
extern (C) char* ngettext(const char*, const char*, c_ulong);
extern (C) char* dngettext(const char*, const char*, const char*, c_ulong);
extern (C) char* dcngettext(const char*, const char*, const char*, c_ulong, int);
extern (C) char* textdomain(const char*);
extern (C) char* bindtextdomain(const char*, const char*);
extern (C) char* bind_textdomain_codeset(const char*, const char*);

string gettext(string text)
in
{
    assert(text);
}
do
{
    return gettext(text.toStringz()).to!string;
}

string ngettext(string singular, string plural, uint num)
in
{
    assert(singular);
    assert(plural);
}
do
{
    return ngettext(singular.toStringz(), plural.toStringz(), num).to!string;
}

string textdomain(string name)
in
{
    assert(name);
}
do
{
    return textdomain(name.toStringz()).to!string;
}

string bindtextdomain(string name, string dir)
in
{
    assert(name);
    assert(dir);
}
do
{
    return bindtextdomain(name.toStringz(), dir.toStringz()).to!string;
}
