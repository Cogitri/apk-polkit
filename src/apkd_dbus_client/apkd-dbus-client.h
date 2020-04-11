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

#include <gio/gio.h>
#include <gmodule.h>
#include <stdbool.h>

typedef enum
{
    addPackage,
    deletePackage,
    listInstalledPackages,
    listAvailablePackages,
    listUpgradablePackages,
    searchForPackages,
    updateRepositories,
    upgradeAllPackages,
    upgradePackage,
} ApkDatabaseOperationsEnum;

typedef struct
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

void apkd_dbus_client_query_async(GPtrArray *packageNameArray, unsigned int len, ApkDatabaseOperationsEnum dbOp, GCancellable *cancellable, GAsyncReadyCallback callback, gpointer userData);

GVariant *apkd_dbus_client_query_finish(GAsyncResult *res, GError **error);

GVariant *apkd_dbus_client_query_sync(GPtrArray *packageNameArray, unsigned int len, ApkDatabaseOperationsEnum dbOp, GCancellable *cancellable, GError **error);
