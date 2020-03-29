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

module apkd.functions;

import apkd.ApkPackage;
import core.stdc.string;
import deimos.apk_toolsd.apk_blob;
import deimos.apk_toolsd.apk_database;
import deimos.apk_toolsd.apk_defines;
import deimos.apk_toolsd.apk_hash;
import deimos.apk_toolsd.apk_io;
import deimos.apk_toolsd.apk_package;
import deimos.apk_toolsd.apk_provider_data;
import deimos.apk_toolsd.apk_solver;
import std.experimental.logger;

/// Taken from apk_defines.h. It's only declared&defined in the
/// header, so it doesn't end up in libapk...
void list_init(list_head* list)
{
    list.next = list;
    list.prev = list;
}

mixin template apkArrayFuncs(string name)
{
    alias T = mixin(name); // works since a few compiler versions ago
    alias A = mixin(name ~ "_array");

    void _func_init(A** a)
    {
        *a = cast(A*) apk_array_resize(null, 0, 0);
    }

    void _func_free(A** a)
    {
        *a = cast(A*) apk_array_resize(*a, 0, 0);
    }

    void _func_resize(A** a, size_t size)
    {
        *a = cast(A*) apk_array_resize(*a, size, T.sizeof);
    }

    void _func_copy(A** a, A* b)
    {
        if (*a == b)
        {
            return;
        }
        mixin(name ~ "_array_resize(a, b.num);");
        memcpy(&(*a).item, &b.item, b.num * T.sizeof);
    }

    T* _func_add(A** a)
    {
        auto size = 1 + (*a).num;
        mixin(name ~ "_array_resize(a, size);");
        return &(*a).item[size - 1];
    }

    mixin("alias " ~ name ~ "_array_free = _func_free;");
    mixin("alias " ~ name ~ "_array_copy = _func_copy;");
    mixin("alias " ~ name ~ "_array_resize = _func_resize;");
    mixin("alias " ~ name ~ "_array_init = _func_init;");
    mixin("alias " ~ name ~ "_array_add = _func_add;");
}

alias apk_string = char*;

static foreach (typeName; [
        "apk_change", "apk_dependency", "apk_protected_path", "apk_provider",
        "apk_string", "apk_xattr",
    ])
{
    mixin apkArrayFuncs!typeName;
}

/// User data passed into recursiveDeletePackages as void pointer
struct DeleteContext
{
public:
    @property bool recursiveDelete() const nothrow
    {
        return m_recursiveDelete;
    }

    @property ref apk_dependency_array* world() nothrow
    {
        return m_world;
    }

    @property uint errors() nothrow
    {
        return m_errors;
    }

    @property void errors(uint count) nothrow
    {
        this.m_errors = count;
    }

private:
    bool m_recursiveDelete;
    apk_dependency_array* m_world;
    uint m_errors;
}

/**
* Recursively delete a pacakge and all of its dependants.
*
* Params:
*   apkPackage = Package which should be deleted
*   ctx        = A DeleteContext which is used to pipe user
*                data into the function.
*/
extern (C) void recursiveDeletePackage(apk_package* apkPackage,
        apk_dependency*, apk_package*, void* ctx) nothrow
{
    auto deleteContext = cast(DeleteContext*) ctx;
    auto world = deleteContext.world;
    apk_deps_del(&world, apkPackage.name);
    if (deleteContext.recursiveDelete)
    {
        apk_pkg_foreach_reverse_dependency(apkPackage,
                APK_FOREACH_INSTALLED | APK_DEP_SATISFIES, &recursiveDeletePackage, ctx);
    }
}

/// Append an apk_package* to an ApkPackage array.
extern (C) int appendApkPackageToArray(apk_hash_item item, void* ctx) nothrow
in
{
    assert(cast(ApkPackage[]*) ctx);
    assert(cast(apk_package*) item);

}
body
{
    auto apkPackages = cast(ApkPackage[]*) ctx;
    auto newPackage = cast(apk_package*) item;
    try
    {
        *apkPackages ~= ApkPackage(*newPackage);
    }
    catch (Exception e)
    {
        try
        {
            error("Appending a new apkPackage to the array failed!");
        }
        catch (Exception e)
        {
        }
        auto retCode = 1;
        // Don't do assert(0) here - that'd end up in release builds!
        assert(retCode == 0);
        return retCode;
    }
    return 0;
}

/// Get the struct containing a certain member only from a pointer to a member
StructType* container_of(StructType, string member)(typeof(__traits(getMember,
        StructType, member))* pointer)
{
    enum offset = __traits(getMember, StructType, member).offsetof;
    return cast(StructType*)(cast(void*) pointer - offset);
}

/**
* Add a new element to an existing list
*
* Params:
*   new_ = The new element to be added
*   head = The list to add the new element to
*/
void apk_list_add(list_head* new_, list_head* head)
{
    head.next.prev = new_;
    new_.next = head.next;
    new_.prev = head;
    head.next = new_;
}
