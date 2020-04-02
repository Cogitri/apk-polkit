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

struct
{
    char *m_name;
    char *m_version;
    char *m_oldVersion;
    char *m_arch;
    char *m_license;
    char *m_origin;
    char *m_maintainer;
    char *m_url;
    char *m_description;
    char *m_commit;
    char *m_filename;
    unsigned long m_installedSize;
    unsigned long m_size;
    time_t m_buildTime;
} apkd_package;

bool apkd_init();

bool apkd_deinit();

void apkd_dbus_client_query_async(GPtrArray *packageNameArray, unsigned int len, ApkDatabaseOperationsEnum dbOp, bool allowUntrustedRepos, GCancellable *cancellable, GAsyncReadyCallback callback, gpointer userData);

GVariant *apkd_dbus_client_query_finish(GAsyncResult *res, GError **error);
