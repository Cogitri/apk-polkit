/*
    Copyright (c) 2020 Rasmus Thomsen

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

module libapk_helper.lib;

import deimos.apk_toolsd.apk_blob;
import deimos.apk_toolsd.apk_database;
import deimos.apk_toolsd.apk_defines;
import deimos.apk_toolsd.apk_package;
import deimos.apk_toolsd.apk_print;
import deimos.apk_toolsd.apk_solver;

import core.stdc.errno;
import std.array;
import std.exception : enforce;
import std.format : format;
import std.stdio : stderr, writeln;
import std.typecons;

class ApkDataBase
{
    this()
    {
        this.dbOptions.open_flags = APK_OPENF_READ | APK_OPENF_WRITE | APK_OPENF_NO_AUTOUPDATE;
        apk_atom_init();
        apk_db_init(&this.db);
        const auto res = apk_db_open(&this.db, &this.dbOptions);
        enforce(res == 0, format("Failed to open apk database due to error '%s'",
                apk_error_str(res)));
    }

    bool updateRepositories(in bool allowUntustedRepos)
    {
        bool res = true;
        const auto apkVerify = allowUntustedRepos ? APK_SIGN_NONE : APK_SIGN_VERIFY;

        for (auto i = APK_REPOSITORY_FIRST_CONFIGURED; i < this.db.num_repos; i++)
        {
            // skip always-configured cache repo
            if (i == APK_REPOSITORY_CACHED)
            {
                continue;
            }

            auto repo = this.db.repos[i];

            const auto apkCacheRes = apk_cache_download(&this.db, &repo,
                    null, apkVerify, FALSE, null, null);

            if (apkCacheRes == -EALREADY)
            {
                res = false;
                continue;
            }
            else if (apkCacheRes != 0)
            {
                stderr.writeln("Failed to download repo '%s' due to error '%s'",
                        repo.url, apkCacheRes);
                this.db.repo_update_errors++;
                res = false;
            }
            else
            {
                this.db.repo_update_counter++;
            }
        }

        return res;
    }

    Tuple!(bool, apk_package[]) getUpgradablePackages()
    {
        bool ret = false;
        apk_package[] packages;
        apk_changeset* changeset = null;

        const auto apkDbCheckRes = apk_db_check_world(&this.db, this.db.world);
        if (apkDbCheckRes != 0)
        {
            stderr.writeln("Missing repository tags; can't continue the upgarde!");
            return tuple(false, packages);
        }

        auto apkSolverRes = apk_solver_solve(&this.db, APK_SOLVERF_UPGRADE,
                this.db.world, changeset);

        if (apkSolverRes == 0)
        {
            auto changes = changeset.changes.item;
            apk_package* new_package, old_package;

            for (auto i = 0; i < changeset.changes.num; i++)
            {

            }
        }
        return tuple(ret, packages);
    }

private:
    apk_database db;
    apk_db_options dbOptions;
}
