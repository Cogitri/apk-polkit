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

import apkd.ApkPackage;
import apkd.exceptions;
static import apkd.functions;
import core.stdc.errno : EALREADY;
import deimos.apk_toolsd.apk_blob;
import deimos.apk_toolsd.apk_database;
import deimos.apk_toolsd.apk_defines;
import deimos.apk_toolsd.apk_hash;
import deimos.apk_toolsd.apk_package;
import deimos.apk_toolsd.apk_print;
import deimos.apk_toolsd.apk_solver;
import deimos.apk_toolsd.apk_version;
import std.algorithm : canFind;
import std.conv : to;
import std.exception : enforce;
import std.experimental.logger;
import std.format : format;
import std.process : pipe, Pipe;
import std.stdio : File, write;
import std.string : toStringz;
import std.utf : toUTFz;

/**
* Class for dealing with the functionality of the APK Database. It can remove/add
* packages, upgrade them, update repositories, search for packages etc.
*/
class ApkDataBase
{
    /**
    * Open the apk database. Be mindful that the lock is held for as long as the
    * object exists, so make sure to destory this as soon as possible. This uses
    * the default root, meaning "/"
    *
    * Params:
    *   readOnly = Whether to open the database in readonly mode, e.g. to list
    *              available packages
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    */
    this(in bool readOnly = false)
    {
        this.dbOptions.lock_wait = TRUE;
        apkd.functions.list_init(&this.dbOptions.repository_list);
        this.m_progressFd = pipe();
        this.openDatabase(readOnly);
        apk_progress_fd = this.m_progressFd.writeEnd.fileno();
    }

    /**
    * Open the apk database. Be mindful that the lock is held for as long as the
    * object exists, so make sure to destory this as soon as possible.
    *
    * Params:
    *   dbRoot      = The root of the database, by default "/"
    *   readOnly    =  Whether to open the database in readonly mode, e.g. to list
    *                  available packages
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    */
    this(in string dbRoot, in bool readOnly = false)
    {
        this.dbOptions.root = dbRoot.toUTFz!(char*);
        this(readOnly);
    }

    /**
    * Open the apk database. Be mindful that the lock is held for as long as the
    * object exists, so make sure to destory this as soon as possible.
    *
    * Params:
    *   dbRoot      = The root of the database, by default "/"
    *   repoUrl     = The URL to an additional repo to consider (e.g. for tests/local repos)
    *   readOnly    =  Whether to open the database in readonly mode, e.g. to list
    *                  available packages
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    */
    this(in string dbRoot, in string repoUrl, in bool readOnly = false)
    {
        this.dbOptions.root = dbRoot.toUTFz!(char*);
        this.additionalRepo = new apk_repository_list;
        this.additionalRepo.url = repoUrl.toUTFz!(char*);
        apkd.functions.list_init(&this.additionalRepo.list);
        apkd.functions.list_init(&this.dbOptions.repository_list);
        apkd.functions.apk_list_add(&this.additionalRepo.list, &this.dbOptions.repository_list);
        this.m_progressFd = pipe();
        this.openDatabase(readOnly);
        apk_progress_fd = this.m_progressFd.writeEnd.fileno();
    }

    /// Destroy the object and close the database
    ~this()
    {
        if (this.db.open_complete)
        {
            apk_db_close(&this.db);
        }
    }

    /**
    * Update all repositories
    *
    * Params:
    *   allowUnstrustedRepos = Whether to also consider repositories whose index has
    *                          an invalid, or missing signature.
    *
    * Returns:
    *   True if all repositories have been updated successfully.
    */
    bool updateRepositories(in bool allowUntustedRepos = false)
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

            this.m_progressFd.writeEnd().write(format("%d/%d\n", i, this.db.num_repos));
            this.m_progressFd.writeEnd().flush();
            auto repo = &this.db.repos[i];

            try
            {
                this.repositoryUpdate(repo, allowUntustedRepos);
            }
            catch (ApkRepoUpdateException)
            {
                res = false;
                errorf("Failed to update repository %s", repo.url.to!string);
            }
        }

        return res;
    }

    /**
    * Get a list of all packages that can be upgraded.
    *
    * Returns:
    *   An array of packages which can be upgraded.
    * Throws:
    *   Throws an ApkSolverException if the solver can't figure out a way to solve
    *   the upgrade, e.g. due to conflicts.
    *   Throws an ApkBrokenWorldException if the db's world is broken.
    */
    ApkPackage[] getUpgradablePackages()
    {
        ApkPackage[] packages;

        extern (C) void addToArray(apk_package* oldPkg, apk_package* newPkg, void* ctx)
        {
            auto arr = cast(ApkPackage[]*) ctx;
            *arr ~= ApkPackage(*oldPkg, *newPkg);
        }

        auto getUpgradeRes = apkd.functions.getUpgradablePackages(&this.db,
                &addToArray, &packages);
        enforce!ApkSolverException(getUpgradeRes == 0,
                format("Couldn't list upgradable packages due to error '%s'",
                    apk_error_str(getUpgradeRes).to!string));

        return packages;
    }

    /**
    * Upgrade all packages in the db's world.
    *
    * Params:
    *   solverFlags = Additional APK_SOLVERF* flags to pass to the solver.
    *
    * Throws:
    *   Throws an ApkSolverException if the solver can't figure out a way to solve
    *   the upgrade, e.g. due to conflicts.
    */
    void upgradeAllPackages(ushort solverFlags = 0)
    {
        auto changeset = this.getAllUpgradeChangeset();
        const auto solverRes = apk_solver_commit_changeset(&this.db, &changeset, this.db.world);
        enforce!ApkSolverException(solverRes == 0,
                format("Couldn't upgrade packages due to error '%s%",
                    apk_error_str(solverRes).to!string));
    }

    /**
    * Upgrade packages specified by pkgnames
    *
    * Params:
    *   pkgnames    = An array of package names to be upgraded.
    *   solverFlags = Additional APK_SOLVERF* flags to pass to the solver.
    *
    * Throws:
    *   Throws a BadDependencyFormatException if the format for the package name isn't valid.
    *   Throws a NoSuchpackageFoundException if the package name specified can't be found.
    *   Throws an ApkDatabaseCommitException if commiting the changes to the database fails, e.g.
    *   due to missing permissions, a conflict, etc.
    */
    void upgradePackage(string[] pkgnames, ushort solverFlags = APK_SOLVERF_IGNORE_UPGRADE)
    {
        apk_dependency_array* worldCopy = null;
        scope (exit)
        {
            apkd.functions.apk_dependency_array_free(&worldCopy);
        }
        apkd.functions.apk_dependency_array_copy(&worldCopy, this.db.world);

        foreach (pkgname; pkgnames)
        {
            auto apkDep = this.packageNameToApkDependency(pkgname);
            apk_deps_add(&worldCopy, &apkDep);
            apk_solver_set_name_flags(apkDep.name, APK_SOLVERF_UPGRADE, APK_SOLVERF_UPGRADE);
        }

        const auto solverCommitRes = apk_solver_commit(&this.db, 0, worldCopy);
        enforce!ApkDatabaseCommitException(solverCommitRes == 0,
                format("Failed to commit changes to the database due to error '%s'!",
                    apk_error_str(solverCommitRes).to!string));
    }

    /**
    * Add (install) packages specified by pkgnames
    *
    * Params:
    *   pkgnames    = An array of package names to be upgraded.
    *   solverFlags = Additional APK_SOLVERF* flags to pass to the solver.
    *
    * Throws:
    *   Throws a BadDependencyFormatException if the format for the package name isn't valid.
    *   Throws a NoSuchpackageFoundException if the package name specified can't be found.
    *   Throws an ApkDatabaseCommitException if commiting the changes to the database fails, e.g.
    *   due to missing permissions, a conflict, etc.
    */
    void addPackage(string[] pkgnames, ushort solverFlags = 0)
    {
        apk_dependency_array* worldCopy = null;
        scope (exit)
        {
            apkd.functions.apk_dependency_array_free(&worldCopy);
        }
        apkd.functions.apk_dependency_array_copy(&worldCopy, this.db.world);

        foreach (pkgname; pkgnames)
        {
            auto dep = packageNameToApkDependency(pkgname);

            apk_deps_add(&worldCopy, &dep);
            apk_solver_set_name_flags(dep.name, solverFlags, solverFlags);
        }

        const auto solverCommitErrorCount = apk_solver_commit(&this.db, solverFlags, worldCopy);
        enforce!ApkDatabaseCommitException(solverCommitErrorCount == 0,
                format("%d error%s occured while installing packages '%s'!",
                    solverCommitErrorCount, solverCommitErrorCount > 1 ? "s" : "", pkgnames));
    }

    /**
    * Delete (uninstall) packages specified by pkgnames and its dependants.
    *
    * Params:
    *   pkgnames    = An array of package names to be upgraded.
    *   solverFlags = Additional APK_SOLVERF* flags to pass to the solver.
    *
    * Throws:
    *   Throws an ApkException if something went wrong while trying to delete packages, e.g.
    *   due to being unable to find the requested package name.
    *   Throws an ApkSolverException if the solver can't figure out a way to solve
    *   the deletion, e.g. due to conflicts.
    *   Throws an ApkDatabaseCommitException if commiting the changes to the database fails, e.g.
    *   due to missing permissions.
    */
    void deletePackage(string[] pkgnames, ushort solverFlags = 0)
    {
        apk_dependency_array* worldCopy = null;
        apk_changeset changeset;
        scope (exit)
        {
            apkd.functions.apk_change_array_free(&changeset.changes);
            apkd.functions.apk_dependency_array_free(&worldCopy);
        }

        apkd.functions.apk_dependency_array_copy(&worldCopy, this.db.world);

        auto deleteContext = apkd.functions.DeleteContext(true, worldCopy, 0);

        this.executeForMatching(pkgnames, apk_foreach_genid(), &deleteName, &deleteContext);

        enforce!ApkException(deleteContext.errors == 0,
                "Something went wrong while deleting packages, see above...");
        const auto solverSolveRes = apk_solver_solve(&this.db, solverFlags,
                deleteContext.world, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));
        const auto solverCommitRes = apk_solver_commit_changeset(&this.db, &changeset, worldCopy);
        enforce!ApkDatabaseCommitException(solverCommitRes == 0,
                format("Failed to commit changes to the database due to error '%s'!",
                    apk_error_str(solverCommitRes).to!string));
    }

    /**
    * Get a list of all packages that are installed.
    *
    * Returns: An array of all installed packages.
    */
    ApkPackage[] getInstalledPackages()
    {
        import apkd.functions : container_of;

        apk_installed_package* installedPackage = null;
        ApkPackage[] ret;

        // dfmt off
        for(
            installedPackage = (&this.db.installed.packages).next.container_of!(apk_installed_package, "installed_pkgs_list");
            &installedPackage.installed_pkgs_list != &this.db.installed.packages;
            installedPackage = installedPackage.installed_pkgs_list.next.container_of!(apk_installed_package, "installed_pkgs_list"))
        {
            ret ~= ApkPackage(*installedPackage.pkg);
        }
        // dfmt on

        return ret;
    }

    /**
    * Get a list of all packages that are installed.
    *
    * Returns: An array of all installed packages.
    * Throws: An ApkListException if something went wrong in iterating over packages
    */
    ApkPackage[] getAvailablePackages()
    {
        ApkPackage[] apkPackages;
        auto apkHashRes = apk_hash_foreach(&this.db.available.packages,
                &apkd.functions.appendApkPackageToArray, &apkPackages);
        enforce!ApkListException(apkHashRes == 0, "Failed to enumerate available packages!");
        return apkPackages;
    }

    /**
    * Get a list of all packages whose name matches one of the names in specs
    *
    * Params:
    *   specs    = An array of package names to search for.
    *
    * Returns: An array of all matching packages.
    * Throws: An ApkListException if something went wrong in iterating over packages
    */
    ApkPackage[] searchPackages(string[] specs)
    {
        ApkPackage[] apkPackages;
        auto context = apkd.functions.SearchContext(specs, &apkPackages);
        auto apkHashRes = apk_hash_foreach(&this.db.available.packages,
                &apkd.functions.appendMatchingApkPackageArray, &context);
        enforce!ApkListException(apkHashRes == 0, "Failed to enumerate available packages!");
        return apkPackages;
    }

    /**
    * Returns read-end of a pipe to which apk writes progress in
    * the format %d/%d where the first digit is the amount of work
    * done and the second digit is the total amount of work to be done.
    */
    @property File progressFd()
    {
        return this.m_progressFd.readEnd();
    }

private:
    /**
    * Update a certain repository.
    *
    * Parameters:
    *   repo                 = The apk_repository to update
    *   allowUnstrustedRepos = Whether to also consider repositories whose index has
    *                          an invalid, or missing signature.
    *
    * Throws: Throws an ApkRepoUpdateException if fetching the repository goes wrong.
    */
    void repositoryUpdate(apk_repository* repo, in bool allowUntrustedRepos)
    {
        const auto apkVerify = allowUntrustedRepos ? APK_SIGN_NONE : APK_SIGN_VERIFY;
        const auto cacheRes = apk_cache_download(&this.db, repo, null,
                apkVerify, FALSE, null, null);
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

    /**
    * Convert a package name to a apk_dependency object
    *
    * Parameters:
    *   pkgname = The name of the package that should be converted
    *
    * Throws:
    *   Throws a NoSuchPackageFoundException if the requested packaage isn't
    *   available.
    *   Throws a BadDependencyFormatException if the package name sepcified
    *   doesn't follow the format name(@tag)([<>~=]version)
    */
    apk_dependency packageNameToApkDependency(string pkgname)
    {
        apk_dependency apk_dependency;
        // If we're trying to add a package via a local apk package archive.
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

    /**
    * Get an apk_changeset for all packages that can be upgraded
    *
    * Params:
    *   solverFlags = Additional APK_SOLVERF* flags to pass to the solver.
    *
    * Throws:
    *   Throws an ApkSolverException if the solver can't figure out a way to solve
    *   the upgrade, e.g. due to conflicts.
    *   Throws an ApkBrokenWorldException if the db's world is broken.
    */
    apk_changeset getAllUpgradeChangeset(ushort solverFlags = 0)
    {
        apk_changeset changeset;
        enforce!ApkBrokenWorldException(apk_db_check_world(&this.db,
                this.db.world) == 0, "Missing repository tags; can't continue the upgrade!");

        const auto solverSolveRes = apk_solver_solve(&this.db,
                APK_SOLVERF_UPGRADE | solverFlags, this.db.world, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));

        return changeset;
    }

    /**
    * Delete the apk_name specified. Used in apk.ApkDatabase.executeForMatching
    *
    * Params:
    *   apk_database = unused
    *   match        = The name of the package that we try to delete
    *   name         = The apk_name we try to delete.
    *   ctx          = A void ptr to a DeleteContext. Used to keep track of errors etc.
    */
    static void deleteName(apk_database*, string match, apk_name* name, void* ctx)
    {
        auto deleteContext = cast(apkd.functions.DeleteContext*) ctx;
        if (name is null)
        {
            errorf("No such package: %s", match);
            deleteContext.errors = deleteContext.errors + 1;
            return;
        }

        auto apkPackage = cast(apk_package*) apk_pkg_get_installed(name);
        if (apkPackage is null)
        {
            auto world = deleteContext.world;
            apk_deps_del(&world, name);
        }
        else
        {
            apkd.functions.recursiveDeletePackage(apkPackage, null, null, ctx);
        }
    }

    /**
    * Execute the function cb for every package which matches
    *
    * Params:
    *   filter = An array of package names we filter through
    *   cb     = Called for each matching package
    *   ctx    = A DeleteContext used for keeping track of errors etc.
    */
    void executeForMatching(string[] filter, uint match, void function(apk_database* db,
            string match, apk_name* name, void* ctx) cb, void* ctx)
    {
        import std.algorithm : canFind;
        import std.utf : toUTFz;

        const uint genid = match & APK_FOREACH_GENID_MASK;
        if (filter is null || filter.length == 0)
        {
            if (!(match & APK_FOREACH_NULL_MATCHES_ALL))
            {
                return;
            }

        }

        foreach (pmatch; filter)
        {
            if (pmatch.canFind('*'))
            {
                return;
            }
        }

        foreach (pmatch; filter)
        {
            auto matchBlob = apk_blob_t(pmatch.length, toUTFz!(char*)(pmatch));
            auto hash = this.db.available.names.ops.hash_key(matchBlob);
            auto name = cast(apk_name*) apk_hash_get_hashed(&this.db.available.names,
                    matchBlob, hash);
            if (genid && name)
            {
                if (name.foreach_genid >= genid)
                {
                    continue;
                }
                name.foreach_genid = genid;
            }
            cb(&this.db, pmatch, name, ctx);
        }

        return;
    }

    /**
    * Open the apk db. Keep in mind that this locks the db, so release it as soon as possible.
    *
    * Params:
    *   readOnly = Whether to open the database in readonly mode, e.g. to list
    *              available packages
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    */
    void openDatabase(in bool readOnly = false)
    {
        if (readOnly)
        {
            this.dbOptions.open_flags = APK_OPENF_READ | APK_OPENF_NO_AUTOUPDATE;
        }
        else
        {
            this.dbOptions.open_flags = APK_OPENF_READ | APK_OPENF_WRITE
                | APK_OPENF_NO_AUTOUPDATE | APK_OPENF_CACHE_WRITE | APK_OPENF_CREATE;

        }
        this.dbOptions.lock_wait = TRUE;
        apk_atom_init();
        apk_db_init(&this.db);
        const auto res = apk_db_open(&this.db, &this.dbOptions);
        enforce!ApkDatabaseOpenException(res == 0,
                format("Failed to open apk database due to error '%s'",
                    apk_error_str(res).to!string));
    }

    apk_database db;
    apk_db_options dbOptions;
    apk_repository_list* additionalRepo;
    Pipe m_progressFd;
}
