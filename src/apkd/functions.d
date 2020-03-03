module apkd.functions;

import core.stdc.string;

import deimos.apk_toolsd.apk_database;
import deimos.apk_toolsd.apk_defines;
import deimos.apk_toolsd.apk_hash;
import deimos.apk_toolsd.apk_io;
import deimos.apk_toolsd.apk_package;
import deimos.apk_toolsd.apk_provider_data;
import deimos.apk_toolsd.apk_solver;

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

    void _func_init(T** a)
    {
        *a = cast(T*) apk_array_resize(null, 0, 0);
    }

    void _func_free(T** a)
    {
        *a = cast(T*) apk_array_resize(*a, 0, 0);
    }

    void _func_resize(T** a, size_t size)
    {
        *a = cast(T*) apk_array_resize(*a, size, T.sizeof);
    }

    void _func_copy(T** a, T* b)
    {
        if (*a == b)
        {
            return;
        }
        *a = cast(T*) apk_array_resize(*a, b.num, b.sizeof);
        memcpy(&(*a).item, &b.item, b.num * T.sizeof);
    }

    mixin("alias " ~ name ~ "_free = _func_free;");
    mixin("alias " ~ name ~ "_copy = _func_copy;");
    mixin("alias " ~ name ~ "_resize = _func_resize;");
    mixin("alias " ~ name ~ "_init = _func_init;");
}

static foreach (typeName; [
        "apk_change_array", "apk_dependency_array", "apk_hash_array",
        "apk_name_array", "apk_package_array", "apk_protected_path_array",
        "apk_provider_array", "apk_string_array", "apk_xattr_array",
    ])
{
    mixin apkArrayFuncs!typeName;
}

struct DeleteContext
{
public:
    @property bool recursiveDelete() const
    {
        return m_recursiveDelete;
    }

    @property ref apk_dependency_array* world()
    {
        return m_world;
    }

    @property uint errors()
    {
        return m_errors;
    }

    @property void errors(uint count)
    {
        this.m_errors = count;
    }

private:
    bool m_recursiveDelete;
    apk_dependency_array* m_world;
    uint m_errors;
}

extern (C) void recursiveDeletePackage(apk_package* apkPackage,
        apk_dependency*, apk_package*, void* ctx)
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
