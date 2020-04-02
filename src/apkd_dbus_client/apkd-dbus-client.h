#include <gio/gio.h>
#include <gmodule.h>
#include <stdbool.h>

enum
{
    addPackage,
    deletePackage,
    listInstalledPackages,
    listAvailablePackages,
    listUpgradablePackages,
    updateRepositories,
    upgradeAllPackages,
    upgradePackage,
} ApkDatabaseOperationsEnum;

bool apkd_init();

bool apkd_deinit();

void apkd_dbus_client_query_async(GPtrArray *packageNameArray, unsigned int len, ApkDatabaseOperationsEnum dbOp, bool allowUntrustedRepos, GCancellable *cancellable, GAsyncReadyCallback callback, gpointer userData);

GVariant *apkd_dbus_client_query_finish(GAsyncResult *res, GError **error);
