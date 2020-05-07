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
import deimos.apk_toolsd.apk_archive;
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
import std.exception : enforce, assumeWontThrow;
import std.experimental.logger;
import std.file : readLink;
import std.format : format;
import std.process : pipe, Pipe;
import std.stdio : File, write;
import std.string : toStringz;
import std.utf : toUTFz;

/**
* Struct for dealing with the functionality of the APK Database. It can remove/add
* packages, upgrade them, update repositories, search for packages etc.
*/
struct ApkDataBase
{
    @disable this();

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
    this(in bool readOnly)
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
    *   dbRoot      = The root of the database, by default "/" (if null)
    *   readOnly    =  Whether to open the database in readonly mode, e.g. to list
    *                  available packages
    *
    * Throws:
    *   Throws an ApkDatabaseOpenException if opening the db fails (e.g. due to missing permissions.)
    */
    this(in string dbRoot, in bool readOnly = false)
    {
        if (dbRoot)
        {
            this.dbOptions.root = dbRoot.toUTFz!(char*);
        }
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
    ApkPackage[] listUpgradablePackages()
    {
        ApkPackage[] packages;

        auto upgradeChangeset = this.getAllUpgradeChangeset();

        foreach (i; 0 .. upgradeChangeset.changes.num)
        {
            auto change = upgradeChangeset.changes.item()[i];

            if (change.new_pkg is null || change.old_pkg is null)
            {
                continue;
            }

            if ((apk_pkg_version_compare(change.new_pkg,
                    change.old_pkg) & (APK_VERSION_GREATER | APK_VERSION_EQUAL))
                    && change.new_pkg != change.old_pkg)
            {
                packages ~= ApkPackage(*change.old_pkg, *change.new_pkg);
            }
        }

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
    void upgradePackages(string[] pkgnames, ushort solverFlags = APK_SOLVERF_IGNORE_UPGRADE)
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
    void addPackages(string[] pkgnames, ushort solverFlags = 0)
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
    void deletePackages(string[] pkgnames, bool recursiveDelete = false, ushort solverFlags = 0)
    {
        apk_dependency_array* worldCopy = null;
        apk_changeset changeset;
        apk_string_array* pkgnameArr;
        scope (exit)
        {
            apkd.functions.apk_change_array_free(&changeset.changes);
            apkd.functions.apk_dependency_array_free(&worldCopy);
            apkd.functions.apk_string_array_free(&pkgnameArr);
        }

        apkd.functions.apk_dependency_array_copy(&worldCopy, this.db.world);

        apkd.functions.apk_string_array_init(&pkgnameArr);
        foreach (pkgname; pkgnames)
        {
            *apkd.functions.apk_string_array_add(&pkgnameArr) = pkgname.toUTFz!(char*);
            apk_deps_del(&worldCopy, packageNameToApkDependency(pkgname).name);
        }

        const auto solverSolveRes = apk_solver_solve(&this.db, solverFlags,
                worldCopy, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));

        foreach (change; changeset.changes.item)
        {
            if (change.new_pkg !is null)
            {
                change.new_pkg.marked = 1;
            }
        }

        string dependants;
        apk_name_foreach_matching(&this.db, pkgnameArr,
                apk_foreach_genid() | APK_FOREACH_MARKED | APK_DEP_SATISFIES,
                &getNotDeletedPackageReason, &dependants);
        if (dependants != "")
        {
            throw new ApkCantDeletedRequiredPackage(format(
                    "package still required by the following packages: %s", dependants));
        }

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
    ApkPackage[] listInstalledPackages()
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
            ret ~= ApkPackage(*installedPackage.pkg, true);
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
    ApkPackage[] listAvailablePackages()
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
    ApkPackage[] searchPackageNames(string[] specs)
    {
        ApkPackage[] apkPackages;
        auto context = apkd.functions.SearchContext(specs, &apkPackages, &this.db);
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

    ApkPackage searchFileOwner(string path)
    {
        auto pathBlob = apk_blob_t(path.length, path.toUTFz!(char*));
        auto pkg = apk_db_get_file_owner(&this.db, pathBlob);
        if (pkg is null)
        {
            auto absolutePath = readLink(path);
            auto absolutePathBlob = apk_blob_t(absolutePath.length, absolutePath.toUTFz!(char*));
            pkg = apk_db_get_file_owner(&this.db, absolutePathBlob);
        }

        enforce!ApkFindFileOwnerException(pkg !is null, "Couldn't find owner of file %s", path);

        return ApkPackage(*pkg, true);
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
        auto apk_dependency = new apk_dependency;
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
            apk_dep_from_pkg(apk_dependency, &this.db, apkPackage);
            enforce!NoSuchPackageFoundException(apk_dependency !is null,
                    format("Couldn't find package %s", pkgname));
            return *apk_dependency;
        }
        else
        {
            apk_blob_t blob = apk_blob_t(pkgname.length, toUTFz!(char*)(pkgname));
            apk_blob_pull_dep(&blob, &this.db, apk_dependency);
            enforce!BadDependencyFormatException(!(blob.ptr is null || blob.len > 0), format(
                    "'%s' is not a correctly formated world dependency, the format should be: name(@tag)([<>~=]version)",
                    pkgname));
            enforce!NoSuchPackageFoundException(apk_dependency !is null,
                    format("Couldn't find package %s", pkgname));
            return *apk_dependency;
        }
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

        scope (exit)
        {
            apkd.functions.apk_change_array_free(&changeset.changes);
        }

        enforce!ApkBrokenWorldException(apk_db_check_world(&this.db,
                this.db.world) == 0, "Missing repository tags; can't continue the upgrade!");

        const auto solverSolveRes = apk_solver_solve(&this.db,
                APK_SOLVERF_UPGRADE | solverFlags, this.db.world, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                format("Failed to calculate dependency graph due to error '%s'!",
                    apk_error_str(solverSolveRes).to!string));

        return changeset;
    }

    struct NotDeletedReasonContext
    {
        apk_name* name;
        string* notRemovedDue;
        uint matches;
    }

    extern (C) static void addNotDeletedPackage(apk_package* pkg,
            apk_dependency*, apk_package*, void* ctx) nothrow
    in
    {
        assert(cast(NotDeletedReasonContext*) ctx,
                "Casting to the expected type of our context failed! This is a bug.");
    }
    do
    {
        auto notDeletedReasonContext = cast(NotDeletedReasonContext*) ctx;
        if (pkg.name.name.to!string != notDeletedReasonContext.name.name.to!string)
        {
            *notDeletedReasonContext.notRemovedDue ~= pkg.name.name.to!string ~ " ";
        }

        foreachReverseDependency(pkg, true, true, false, &addNotDeletedPackage, ctx);
        foreach (dep; pkg.install_if.item)
        {
            foreach (provider; dep.name.providers.item)
            {
                if (provider.pkg.marked && !apk_pkg_match_genid(provider.pkg,
                        notDeletedReasonContext.matches))
                {
                    addNotDeletedPackage(provider.pkg, null, null, ctx);
                }
            }
        }
    }

    /**
    * Get the dependants that depend on a package and stop it from being deleted.
    * Params:
    *   apk_database = unused
    *   match        = The name of the package that we try to delete. Unused.
    *   name         = The apk_name we try to delete.
    *   ctx          = A void ptr to a DeleteContext. Used to keep track of errors etc.
    */
    extern (C) static void getNotDeletedPackageReason(apk_database*,
            const char*, apk_name* name, void* ctx) nothrow
    in
    {
        assert(cast(string*) ctx,
                "Casting to the expected type of our context failed! This is a bug.");
    }
    do
    {
        auto notRemovedDue = cast(string*) ctx;
        auto notDeletedReasonContext = NotDeletedReasonContext(name, notRemovedDue,
                apk_foreach_genid() | APK_FOREACH_MARKED | APK_DEP_SATISFIES);
        foreach (provider; name.providers.item)
        {
            if (provider.pkg.marked)
            {
                addNotDeletedPackage(provider.pkg, null, null, &notDeletedReasonContext);
            }
        }
    }

    alias reverseDepFunc = extern (C) void function(apk_package* pkg,
            apk_dependency* dep, apk_package* pkg, void* ctx) nothrow;

    static foreachReverseDependency(apk_package* pkg, bool marked,
            bool installed, bool one_dep_only, reverseDepFunc cb, void* ctx) nothrow
    {
        foreach (reverseDep; pkg.name.rdepends.item)
        {
            foreach (depPkg; reverseDep.providers.item)
            {
                if ((installed && depPkg.pkg.ipkg is null) || (marked && !depPkg.pkg.marked))
                {
                    continue;
                }
                cb(depPkg.pkg, null, null, ctx);
            }
        }
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

        version (testing)
        {
            this.db.extract_flags = APK_EXTRACTF_NO_CHOWN;
            apk_flags = APK_ALLOW_UNTRUSTED;
        }
    }

    apk_database db;
    apk_db_options dbOptions;
    apk_repository_list* additionalRepo;
    Pipe m_progressFd;
}
