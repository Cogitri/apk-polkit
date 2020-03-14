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
import std.experimental.logger;
import std.format : format;
import std.string : toStringz;
import std.typecons;
import std.utf : toUTFz;

import apkd.ApkPackage;
import apkd.exceptions;
static import apkd.functions;

class ApkDataBase
{
    this()
    {
        this.dbOptions.open_flags = APK_OPENF_READ | APK_OPENF_WRITE
            | APK_OPENF_NO_AUTOUPDATE | APK_OPENF_CACHE_WRITE | APK_OPENF_CREATE;
        this.dbOptions.lock_wait = TRUE;
        apkd.functions.list_init(&this.dbOptions.repository_list);
        apk_atom_init();
        apk_db_init(&this.db);
        const auto res = apk_db_open(&this.db, &this.dbOptions);
        enforce!ApkDatabaseOpenException(res == 0,
                format("Failed to open apk database due to error '%s'",
                    apk_error_str(res).to!string));
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
                criticalf("Failed to download repo '%s' due to error '%s'",
                        repo.url, apk_error_str(apkCacheRes).to!string);
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
        auto changeset = this.getAllUpgradeChangeset();

        for (auto i = 0; i < changeset.changes.num; i++)
        {
            auto newPackage = changeset.changes.item[i].new_pkg;
            auto oldPackage = changeset.changes.item[i].old_pkg;
            auto apkPackage = new ApkPackage(*oldPackage, *newPackage);
            packages ~= apkPackage;
        }

        return packages;
    }

    void upgradeAllPackages(ushort solverFlags = 0)
    {
        auto changeset = this.getAllUpgradeChangeset();
        const auto solverRes = apk_solver_commit_changeset(&this.db, &changeset, this.db.world);
        enforce!ApkSolverException(solverRes == 0,
                format("Couldn't upgrade packages due to error '%s%",
                    apk_error_str(solverRes).to!string));
    }

    void upgradePackage(string pkgname, ushort solverFlags = 0)
    {
        apk_changeset changeset;
        auto apkDep = this.packageNameToApkDependency(pkgname);
        apk_solver_set_name_flags(apkDep.name, solverFlags, solverFlags);
        const auto solverSolveRes = apk_solver_solve(&this.db,
                APK_SOLVERF_UPGRADE, this.db.world, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));
        const auto solverCommitRes = apk_solver_commit_changeset(&this.db,
                &changeset, this.db.world);
        enforce!ApkDatabaseCommitException(solverCommitRes == 0,
                format("Failed to commit changes to the database due to error '%s'!",
                    apk_error_str(solverCommitRes).to!string));
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
        const auto solverSolveRes = apk_solver_solve(&this.db, solverFlags,
                world_copy, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));
        const auto solverCommitRes = apk_solver_commit_changeset(&this.db, &changeset, world_copy);
        enforce!ApkDatabaseCommitException(solverCommitRes == 0,
                format("Failed to commit changes to the database due to error '%s'!",
                    apk_error_str(solverCommitRes).to!string));
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
        enforce!NoSuchPackageFoundException(name !is null, "No such package: %s", pkgname);
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

        const auto solverSolveRes = apk_solver_solve(&this.db, solverFlags,
                worldCopy, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));
        const auto solverCommitRes = apk_solver_commit_changeset(&this.db, &changeset, worldCopy);
        enforce!ApkDatabaseCommitException(solverCommitRes == 0,
                format("Failed to commit changes to the database due to error '%s'!",
                    apk_error_str(solverCommitRes).to!string));
    }

    ApkPackage[] getInstalledPackages()
    {
        import apkd.functions : container_of;

        apk_installed_package* installedPackage = null;
        ApkPackage[] ret;

        installedPackage = (&this.db.installed.packages).next.container_of!(
                apk_installed_package, "installed_pkgs_list");

        if (installedPackage is null
                || installedPackage.installed_pkgs_list.next == &this.db.installed.packages)
        {
            warning("Couldn't find any installed packages!");
            return ret;
        }

        while (installedPackage.installed_pkgs_list != this.db.installed.packages)
        {
            ret ~= new ApkPackage(*installedPackage.pkg);
            installedPackage = installedPackage.installed_pkgs_list.next.next.container_of!(
                    apk_installed_package, "installed_pkgs_list");
        }

        return ret;
    }

    ApkPackage[] getAvailablePackages()
    {
        ApkPackage[] apkPackages;
        auto apkHashRes = apk_hash_foreach(&this.db.available.packages,
                &apkd.functions.appendApkPackageToArray, cast(void*) apkPackages);
        enforce(apkHashRes < 0, "Failed to enumerate available packages!");
        return apkPackages;
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
            throw new ApkRepoUpdateException(format("Fetch of repository %s failed due to error '%s'!",
                    repo.url, apk_error_str(cacheRes).to!string));
        }
    }

    apk_dependency packageNameToApkDependency(string pkgname)
    {
        apk_dependency apk_dependency;
        if (pkgname.canFind(".apk"))
        {
            apk_package* apkPackage = null;
            apk_sign_ctx ctx = void;
            apk_sign_ctx_init(&ctx, APK_SIGN_VERIFY_AND_GENERATE, null, this.db.keys_fd);
            scope (exit)
            {
                apk_sign_ctx_free(&ctx);
            }
            auto pkgRes = apk_pkg_read(&this.db, pkgname.toStringz, &ctx, &apkPackage);
            enforce!NoSuchPackageFoundException(pkgRes == 0, format("%s: %s",
                    pkgname, apk_error_str(pkgRes).to!string));
            apk_dep_from_pkg(&apk_dependency, &this.db, apkPackage);
            return apk_dependency;
        }
        else
        {
            apk_blob_t blob = apk_blob_t(pkgname.length, toUTFz!(char*)(pkgname));
            apk_blob_pull_dep(&blob, &this.db, &apk_dependency);
            enforce!BadDependencyFormatException(!(blob.ptr is null || blob.len > 0), format(
                    "'%s' is not a correctly formated world dependency, the format should be: name(@tag)([<>~=]version)"));
        }

        return apk_dependency;
    }

    apk_changeset getAllUpgradeChangeset()
    {
        apk_changeset changeset;
        enforce(apk_db_check_world(&this.db, this.db.world) == 0,
                "Missing repository tags; can't continue the upgarde!");

        const auto solverSolveRes = apk_solver_solve(&this.db,
                APK_SOLVERF_UPGRADE, this.db.world, &changeset);

        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));

        return changeset;
    }

    apk_database db;
    apk_db_options dbOptions;
}
