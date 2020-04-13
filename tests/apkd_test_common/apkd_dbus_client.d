/*
 * This file is generated by gdbus-codegen, do not modify it.
 *
 * The license of this code is the same as for the D-Bus interface description
 * it was derived from. Note that it links to GLib, so must comply with the
 * LGPL linking clauses.
 */
module tests.apkd_test_common.apkd_dbus_client;

import gio.c.types;
import glib.c.types;

extern (C):

/* ------------------------------------------------------------------------ */
/* Declarations for dev.Cogitri.apkPolkit.Helper */

extern (D) auto APKD_HELPER(T)(auto ref T o)
{
        return G_TYPE_CHECK_INSTANCE_CAST!ApkdHelper(o, APKD_TYPE_HELPER);
}

extern (D) auto APKD_IS_HELPER(T)(auto ref T o)
{
        return G_TYPE_CHECK_INSTANCE_TYPE(o, APKD_TYPE_HELPER);
}

extern (D) auto APKD_HELPER_GET_IFACE(T)(auto ref T o)
{
        return G_TYPE_INSTANCE_GET_INTERFACE!ApkdHelperIface(o, APKD_TYPE_HELPER);
}

struct _ApkdHelper;
alias ApkdHelper = _ApkdHelper;
alias ApkdHelperIface = _ApkdHelperIface;

struct _ApkdHelperIface
{
        GTypeInterface parent_iface;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation,
                        const(char*)* arg_packages) handle_add_package;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation,
                        const(char*)* arg_packages) handle_delete_package;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation) handle_list_available_packages;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation) handle_list_installed_packages;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation) handle_list_upgradable_packages;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation,
                        const(char*)* arg_packages) handle_search_for_packages;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation) handle_update_repositories;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation) handle_upgrade_all_packages;

        bool function(ApkdHelper* object, GDBusMethodInvocation* invocation,
                        const(char*)* arg_packages) handle_upgrade_package;

        bool function(ApkdHelper* object) get_allow_untrusted_repos;

        const(char)* function(ApkdHelper* object) get_root;

        void function(ApkdHelper* object, uint arg_progressPercentage) progress_notification;
}

alias ApkdHelper_autoptr = _ApkdHelper*;
void glib_autoptr_clear_ApkdHelper(ApkdHelper* _ptr);
void glib_autoptr_cleanup_ApkdHelper(ApkdHelper** _ptr);
void glib_listautoptr_cleanup_ApkdHelper(GList** _l);
void glib_slistautoptr_cleanup_ApkdHelper(GSList** _l);
void glib_queueautoptr_cleanup_ApkdHelper(GQueue** _q);

GDBusInterfaceInfo* apkd_helper_interface_info();
uint apkd_helper_override_properties(GObjectClass* klass, uint property_id_begin);

/* D-Bus method call completion functions: */
void apkd_helper_complete_update_repositories(ApkdHelper* object, GDBusMethodInvocation* invocation);

void apkd_helper_complete_upgrade_package(ApkdHelper* object, GDBusMethodInvocation* invocation);

void apkd_helper_complete_upgrade_all_packages(ApkdHelper* object,
                GDBusMethodInvocation* invocation);

void apkd_helper_complete_delete_package(ApkdHelper* object, GDBusMethodInvocation* invocation);

void apkd_helper_complete_add_package(ApkdHelper* object, GDBusMethodInvocation* invocation);

void apkd_helper_complete_list_available_packages(ApkdHelper* object,
                GDBusMethodInvocation* invocation, GVariant* matchingPackages);

void apkd_helper_complete_list_installed_packages(ApkdHelper* object,
                GDBusMethodInvocation* invocation, GVariant* matchingPackages);

void apkd_helper_complete_list_upgradable_packages(ApkdHelper* object,
                GDBusMethodInvocation* invocation, GVariant* matchingPackages);

void apkd_helper_complete_search_for_packages(ApkdHelper* object,
                GDBusMethodInvocation* invocation, GVariant* matchingPackages);

/* D-Bus signal emissions functions: */
void apkd_helper_emit_progress_notification(ApkdHelper* object, uint arg_progressPercentage);

/* D-Bus method calls: */
void apkd_helper_call_update_repositories(ApkdHelper* proxy,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_update_repositories_finish(ApkdHelper* proxy,
                GAsyncResult* res, GError** error);

bool apkd_helper_call_update_repositories_sync(ApkdHelper* proxy,
                GCancellable* cancellable, GError** error);

void apkd_helper_call_upgrade_package(ApkdHelper* proxy, const(char*)* arg_packages,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_upgrade_package_finish(ApkdHelper* proxy, GAsyncResult* res, GError** error);

bool apkd_helper_call_upgrade_package_sync(ApkdHelper* proxy,
                const(char*)* arg_packages, GCancellable* cancellable, GError** error);

void apkd_helper_call_upgrade_all_packages(ApkdHelper* proxy,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_upgrade_all_packages_finish(ApkdHelper* proxy,
                GAsyncResult* res, GError** error);

bool apkd_helper_call_upgrade_all_packages_sync(ApkdHelper* proxy,
                GCancellable* cancellable, GError** error);

void apkd_helper_call_delete_package(ApkdHelper* proxy, const(char*)* arg_packages,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_delete_package_finish(ApkdHelper* proxy, GAsyncResult* res, GError** error);

bool apkd_helper_call_delete_package_sync(ApkdHelper* proxy,
                const(char*)* arg_packages, GCancellable* cancellable, GError** error);

void apkd_helper_call_add_package(ApkdHelper* proxy, const(char*)* arg_packages,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_add_package_finish(ApkdHelper* proxy, GAsyncResult* res, GError** error);

bool apkd_helper_call_add_package_sync(ApkdHelper* proxy,
                const(char*)* arg_packages, GCancellable* cancellable, GError** error);

void apkd_helper_call_list_available_packages(ApkdHelper* proxy,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_list_available_packages_finish(ApkdHelper* proxy,
                GVariant** out_matchingPackages, GAsyncResult* res, GError** error);

bool apkd_helper_call_list_available_packages_sync(ApkdHelper* proxy,
                GVariant** out_matchingPackages, GCancellable* cancellable, GError** error);

void apkd_helper_call_list_installed_packages(ApkdHelper* proxy,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_list_installed_packages_finish(ApkdHelper* proxy,
                GVariant** out_matchingPackages, GAsyncResult* res, GError** error);

bool apkd_helper_call_list_installed_packages_sync(ApkdHelper* proxy,
                GVariant** out_matchingPackages, GCancellable* cancellable, GError** error);

void apkd_helper_call_list_upgradable_packages(ApkdHelper* proxy,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_list_upgradable_packages_finish(ApkdHelper* proxy,
                GVariant** out_matchingPackages, GAsyncResult* res, GError** error);

bool apkd_helper_call_list_upgradable_packages_sync(ApkdHelper* proxy,
                GVariant** out_matchingPackages, GCancellable* cancellable, GError** error);

void apkd_helper_call_search_for_packages(ApkdHelper* proxy, const(char*)* arg_packages,
                GCancellable* cancellable, GAsyncReadyCallback callback, void* user_data);

bool apkd_helper_call_search_for_packages_finish(ApkdHelper* proxy,
                GVariant** out_matchingPackages, GAsyncResult* res, GError** error);

bool apkd_helper_call_search_for_packages_sync(ApkdHelper* proxy, const(char*)* arg_packages,
                GVariant** out_matchingPackages, GCancellable* cancellable, GError** error);

/* D-Bus property accessors: */
bool apkd_helper_get_allow_untrusted_repos(ApkdHelper* object);
void apkd_helper_set_allow_untrusted_repos(ApkdHelper* object, bool value);

const(char)* apkd_helper_get_root(ApkdHelper* object);
char* apkd_helper_dup_root(ApkdHelper* object);
void apkd_helper_set_root(ApkdHelper* object, const(char)* value);

/* ---- */

extern (D) auto APKD_HELPER_PROXY(T)(auto ref T o)
{
        return G_TYPE_CHECK_INSTANCE_CAST!ApkdHelperProxy(o, APKD_TYPE_HELPER_PROXY);
}

extern (D) auto APKD_HELPER_PROXY_CLASS(T)(auto ref T k)
{
        return G_TYPE_CHECK_CLASS_CAST!ApkdHelperProxyClass(k, APKD_TYPE_HELPER_PROXY);
}

extern (D) auto APKD_HELPER_PROXY_GET_CLASS(T)(auto ref T o)
{
        return G_TYPE_INSTANCE_GET_CLASS!ApkdHelperProxyClass(o, APKD_TYPE_HELPER_PROXY);
}

extern (D) auto APKD_IS_HELPER_PROXY(T)(auto ref T o)
{
        return G_TYPE_CHECK_INSTANCE_TYPE(o, APKD_TYPE_HELPER_PROXY);
}

extern (D) auto APKD_IS_HELPER_PROXY_CLASS(T)(auto ref T k)
{
        return G_TYPE_CHECK_CLASS_TYPE(k, APKD_TYPE_HELPER_PROXY);
}

alias ApkdHelperProxy = _ApkdHelperProxy;
alias ApkdHelperProxyClass = _ApkdHelperProxyClass;
struct _ApkdHelperProxyPrivate;
alias ApkdHelperProxyPrivate = _ApkdHelperProxyPrivate;

struct _ApkdHelperProxy
{
        /*< private >*/
        GDBusProxy parent_instance;
        ApkdHelperProxyPrivate* priv;
}

struct _ApkdHelperProxyClass
{
        GDBusProxyClass parent_class;
}

alias ApkdHelperProxy_autoptr = _ApkdHelperProxy*;
void glib_autoptr_clear_ApkdHelperProxy(ApkdHelperProxy* _ptr);
void glib_autoptr_cleanup_ApkdHelperProxy(ApkdHelperProxy** _ptr);
void glib_listautoptr_cleanup_ApkdHelperProxy(GList** _l);
void glib_slistautoptr_cleanup_ApkdHelperProxy(GSList** _l);
void glib_queueautoptr_cleanup_ApkdHelperProxy(GQueue** _q);

void apkd_helper_proxy_new(GDBusConnection* connection, GDBusProxyFlags flags, const(char)* name,
                const(char)* object_path, GCancellable* cancellable,
                GAsyncReadyCallback callback, void* user_data);
ApkdHelper* apkd_helper_proxy_new_finish(GAsyncResult* res, GError** error);
ApkdHelper* apkd_helper_proxy_new_sync(GDBusConnection* connection, GDBusProxyFlags flags,
                const(char)* name, const(char)* object_path,
                GCancellable* cancellable, GError** error);

void apkd_helper_proxy_new_for_bus(GBusType bus_type, GDBusProxyFlags flags, const(char)* name,
                const(char)* object_path, GCancellable* cancellable,
                GAsyncReadyCallback callback, void* user_data);
ApkdHelper* apkd_helper_proxy_new_for_bus_finish(GAsyncResult* res, GError** error);
ApkdHelper* apkd_helper_proxy_new_for_bus_sync(GBusType bus_type, GDBusProxyFlags flags,
                const(char)* name, const(char)* object_path,
                GCancellable* cancellable, GError** error);

/* ---- */

extern (D) auto APKD_HELPER_SKELETON(T)(auto ref T o)
{
        return G_TYPE_CHECK_INSTANCE_CAST!ApkdHelperSkeleton(o, APKD_TYPE_HELPER_SKELETON);
}

extern (D) auto APKD_HELPER_SKELETON_CLASS(T)(auto ref T k)
{
        return G_TYPE_CHECK_CLASS_CAST!ApkdHelperSkeletonClass(k, APKD_TYPE_HELPER_SKELETON);
}

extern (D) auto APKD_HELPER_SKELETON_GET_CLASS(T)(auto ref T o)
{
        return G_TYPE_INSTANCE_GET_CLASS!ApkdHelperSkeletonClass(o, APKD_TYPE_HELPER_SKELETON);
}

extern (D) auto APKD_IS_HELPER_SKELETON(T)(auto ref T o)
{
        return G_TYPE_CHECK_INSTANCE_TYPE(o, APKD_TYPE_HELPER_SKELETON);
}

extern (D) auto APKD_IS_HELPER_SKELETON_CLASS(T)(auto ref T k)
{
        return G_TYPE_CHECK_CLASS_TYPE(k, APKD_TYPE_HELPER_SKELETON);
}

alias ApkdHelperSkeleton = _ApkdHelperSkeleton;
alias ApkdHelperSkeletonClass = _ApkdHelperSkeletonClass;
struct _ApkdHelperSkeletonPrivate;
alias ApkdHelperSkeletonPrivate = _ApkdHelperSkeletonPrivate;

struct _ApkdHelperSkeleton
{
        /*< private >*/
        GDBusInterfaceSkeleton parent_instance;
        ApkdHelperSkeletonPrivate* priv;
}

struct _ApkdHelperSkeletonClass
{
        GDBusInterfaceSkeletonClass parent_class;
}

alias ApkdHelperSkeleton_autoptr = _ApkdHelperSkeleton*;
void glib_autoptr_clear_ApkdHelperSkeleton(ApkdHelperSkeleton* _ptr);
void glib_autoptr_cleanup_ApkdHelperSkeleton(ApkdHelperSkeleton** _ptr);
void glib_listautoptr_cleanup_ApkdHelperSkeleton(GList** _l);
void glib_slistautoptr_cleanup_ApkdHelperSkeleton(GSList** _l);
void glib_queueautoptr_cleanup_ApkdHelperSkeleton(GQueue** _q);

ApkdHelper* apkd_helper_skeleton_new();

/* __APKD_DBUS_CLIENT_H__ */
