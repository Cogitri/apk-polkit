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

#include <apk/apk_blob.h>
#include <apk/apk_database.h>
#include <apk/apk_defines.h>
#include <apk/apk_version.h>
#include <apk/apk_solver.h>
#include <apk/apk_package.h>
#include <stdio.h>

static int checkUpgrade(struct apk_change *change)
{
    if (change->new_pkg == NULL || change->old_pkg == NULL)
        return 0;

    /* Count swapping package as upgrade too - this can happen if
         * same package version is used after it was rebuilt against
         * newer libraries. Basically, different (and probably newer)
         * package, but equal version number. */
    if ((apk_pkg_version_compare(change->new_pkg, change->old_pkg) &
         (APK_VERSION_GREATER | APK_VERSION_EQUAL)) &&
        (change->new_pkg != change->old_pkg))
        return 1;

    return 0;
}

int getUpgradablePackages(struct apk_database *db, void cb(struct apk_package *oldPkg, struct apk_package *newPkg, void *ctx), void *ctx)
{
    struct apk_changeset changeset = {};
    struct apk_change *change;
    int r;

    r = apk_solver_solve(db, APK_SOLVERF_UPGRADE, db->world, &changeset);

    if (r != 0)
    {
        apk_change_array_free(&changeset.changes);
        return r;
    }

    foreach_array_item(change, changeset.changes)
    {
        if (checkUpgrade(change))
        {
            cb(change->old_pkg, change->new_pkg, ctx);
        }
    }

    apk_change_array_free(&changeset.changes);
    return 0;
}
