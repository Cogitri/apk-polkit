module apkd.functions;

import core.stdc.string;

import deimos.apk_toolsd.apk_blob;
import deimos.apk_toolsd.apk_database;
import deimos.apk_toolsd.apk_defines;
import deimos.apk_toolsd.apk_hash;
import deimos.apk_toolsd.apk_io;
import deimos.apk_toolsd.apk_package;
import deimos.apk_toolsd.apk_provider_data;
import deimos.apk_toolsd.apk_solver;

import apkd.ApkPackage : ApkPackage;

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

extern (C) int appendApkPackageToArray(apk_hash_item item, void* ctx)
{
    auto apkPackages = cast(ApkPackage[]*) ctx;
    auto newPackage = cast(apk_package*) item;
    *apkPackages ~= new ApkPackage(*newPackage);
    return 0;
}

StructType* container_of(StructType, string member)(typeof(__traits(getMember,
        StructType, member))* pointer)
{
    enum offset = __traits(getMember, StructType, member).offsetof;
    return cast(StructType*)(cast(void*) pointer - offset);
}
