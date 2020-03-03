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

module apkd.ApkDataBase;

import deimos.apk_toolsd.apk_blob;
import deimos.apk_toolsd.apk_database;
import deimos.apk_toolsd.apk_defines;
import deimos.apk_toolsd.apk_hash;
import deimos.apk_toolsd.apk_package;
import deimos.apk_toolsd.apk_print;
import deimos.apk_toolsd.apk_solver;

import core.stdc.errno;

import std.algorithm : canFind;
import std.array;
import std.conv;
import std.exception;
import std.format : format;
import std.stdio : stderr, writeln;
import std.string : toStringz;
import std.typecons;
import std.utf : toUTFz;

import apkd.ApkPackage;
static import apkd.functions;

/// Thrown if updating a repository fails.
class RepoUpdateException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__) @safe
    {
        super(msg, file, line);
    }
}

class ApkDataBase
{
    this()
    {
        this.dbOptions.open_flags = APK_OPENF_READ | APK_OPENF_WRITE
            | APK_OPENF_NO_AUTOUPDATE | APK_OPENF_CACHE_WRITE | APK_OPENF_CREATE;
        apkd.functions.list_init(&this.dbOptions.repository_list);
        apk_atom_init();
        apk_db_init(&this.db);
        const auto res = apk_db_open(&this.db, &this.dbOptions);
        enforce(res == 0, format("Failed to open apk database due to error '%s'",
                apk_error_str(res)));
    }

    ~this()
    {
        if (this.db.open_complete)
        {
            apk_db_close(&this.db);
        }
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

    ApkPackage[] getUpgradablePackages()
    {
        ApkPackage[] packages;
        apk_changeset changeset;

        enforce(apk_db_check_world(&this.db, this.db.world) == 0,
                "Missing repository tags; can't continue the upgarde!");

        const auto apkSolverRes = apk_solver_solve(&this.db,
                APK_SOLVERF_UPGRADE, this.db.world, &changeset);

        if (apkSolverRes == 0)
        {
            auto changes = changeset.changes.item;

            writeln(changeset.changes.num);

            for (auto i = 0; i < changeset.changes.num; i++)
            {
                auto newPackage = changes[i].new_pkg;
                auto oldPackage = changes[i].old_pkg;
                auto apkPackage = new ApkPackage(*oldPackage, *newPackage);
                packages ~= apkPackage;
            }
        }
        return packages;
    }

    void addPackage(string pkgname, ushort solverFlags = 0)
    {
        auto dep = packageNameToApkDependency(pkgname);
        apk_dependency_array* world_copy = null;
        scope (exit)
        {
            apkd.functions.apk_dependency_array_free(&world_copy);
        }
        apk_changeset changeset;

        apk_deps_add(&world_copy, &dep);
        apk_solver_set_name_flags(dep.name, solverFlags, solverFlags);
        enforce(apk_solver_solve(&this.db, solverFlags, world_copy,
                &changeset) == 0, "Failed to calculate dependency graph!");
        enforce(apk_solver_commit_changeset(&this.db, &changeset,
                world_copy) == 0, "Failed to commit changes to the database!");
    }

    void deletePackage(string pkgname, ushort solverFlags = 0)
    {
        auto pkgnameBlob = apk_blob_t(pkgname.length, toUTFz!(char*)(pkgname));
        apk_dependency_array* worldCopy = null;
        apk_changeset changeset;
        scope (exit)
        {
            apkd.functions.apk_change_array_free(&changeset.changes);
            apkd.functions.apk_dependency_array_free(&worldCopy);
        }

        apkd.functions.apk_dependency_array_copy(&worldCopy, this.db.world);

        auto hash = this.db.available.names.ops.hash_key(pkgnameBlob);
        auto name = cast(apk_name*) apk_hash_get_hashed(&this.db.available.names,
                pkgnameBlob, hash);

        enforce(name !is null, "No such package: %s", pkgname);

        auto deleteContext = apkd.functions.DeleteContext(true, worldCopy, 0);

        auto apkPackage = cast(apk_package*) apk_pkg_get_installed(name);
        if (apkPackage is null)
        {
            apk_deps_del(&worldCopy, name);
        }
        else
        {
            apkd.functions.recursiveDeletePackage(apkPackage, null, null, &deleteContext);
        }

        enforce(apk_solver_solve(&this.db, solverFlags, worldCopy, &changeset) == 0);
        apk_solver_commit_changeset(&this.db, &changeset, worldCopy);
    }

private:
    void repositoryUpdate(apk_repository* repo)
    {
        const auto apkVerify = FALSE ? APK_SIGN_NONE : APK_SIGN_VERIFY;

        const auto cacheRes = apk_cache_download(&this.db, repo, null, apkVerify, 1, null, null);

        if (cacheRes == 0)
        {
            this.db.repo_update_counter++;
        }
        else if (cacheRes != -EALREADY)
        {
            this.db.repo_update_errors++;
            throw new RepoUpdateException(format("Fetch of repository %s failed due to error '%s'!",
                    repo.url, apk_error_str(cacheRes)));
        }
    }

    apk_dependency packageNameToApkDependency(string pkgname)
    {
        apk_dependency apk_dependency;

        if (pkgname.canFind(".apk"))
        {
            apk_package* apkPackage = null;
            apk_sign_ctx ctx;

            apk_sign_ctx_init(&ctx, APK_SIGN_VERIFY_AND_GENERATE, null, this.db.keys_fd);
            scope (exit)
            {
                apk_sign_ctx_free(&ctx);
            }
            auto pkgRes = apk_pkg_read(&this.db, pkgname.toStringz, &ctx, &apkPackage);
            enforce(pkgRes == 0, format("%s: %s", pkgname, apk_error_str(pkgRes)));
            apk_dep_from_pkg(&apk_dependency, &this.db, apkPackage);
            return apk_dependency;
        }
        else
        {
            apk_blob_t blob = apk_blob_t(pkgname.length, toUTFz!(char*)(pkgname));
            apk_blob_pull_dep(&blob, &this.db, &apk_dependency);
            enforce(!(blob.ptr is null || blob.len > 0), format(
                    "'%s' is not a correctly formated world dependency, the forma should be: name(@tag)([<>~=]version)"));
        }

        return apk_dependency;
    }

    apk_database db;
    apk_db_options dbOptions;
}
