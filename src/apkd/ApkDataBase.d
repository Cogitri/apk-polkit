/*
    Copyright (c) 2020 Rasmus Thomsen <oss@cogitri.dev>

    This file is part of apk-polkit (see https://gitlab.alpinelinux.org/Cogitri/apk-polkit).

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
import apkd.ApkRepository;
import apkd.exceptions;
static import apkd.functions;
import apkd_common.gettext;
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
import std.algorithm : canFind, sort, uniq, startsWith;
import std.array : join, replace, split;
import std.conv : to;
import std.exception : assumeWontThrow, enforce;
import std.experimental.logger;
import std.file : readLink;
import std.format : format;
import std.process : pipe, Pipe;
import std.range : empty;
import std.stdio : File, write;
import std.string : toStringz, strip;
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
    ApkPackage[] listUpgradablePackages(ushort solverFlags = APK_SOLVERF_AVAILABLE)
    {
        ApkPackage[] packages;

        auto upgradeChangeset = this.getAllUpgradeChangeset(solverFlags);

        scope (exit)
        {
            apkd.functions.apk_change_array_free(&upgradeChangeset.changes);
        }

        foreach (i; 0 .. upgradeChangeset.changes.num)
        {
            auto change = upgradeChangeset.changes.item()[i];

            if (change.old_pkg is null && change.new_pkg !is null)
            {
                packages ~= ApkPackage(change.new_pkg);
            }
            else if (change.old_pkg !is null && change.new_pkg !is null && (apk_pkg_version_compare(change.new_pkg,
                    change.old_pkg) & (APK_VERSION_GREATER | APK_VERSION_EQUAL))
                    && change.new_pkg != change.old_pkg)
            {
                packages ~= ApkPackage(change.old_pkg, change.new_pkg);
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
    void upgradeAllPackages(ushort solverFlags = APK_SOLVERF_AVAILABLE)
    {
        auto changeset = this.getAllUpgradeChangeset(solverFlags);
        scope (exit)
        {
            apkd.functions.apk_change_array_free(&changeset.changes);
        }
        const auto solverErrorCount = apk_solver_commit_changeset(&this.db,
                &changeset, this.db.world);
        enforce!ApkSolverException(solverErrorCount == 0,
                /* Translators: Do not translate 'apk upgrade -a', it's the command the user should run */
                gettext(
                    "Failed to upgrade all packages! Please run 'apk upgrade -a' for more information."));
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
    void upgradePackages(string[] pkgnames,
            ushort solverFlags = APK_SOLVERF_UPGRADE | APK_SOLVERF_AVAILABLE)
    {
        // if a subpackage is scheduled to be upgraded, also upgrade the mainpackage.
        apk_dependency*[] toBeUpgraded;
        toBeUpgraded.reserve(pkgnames.length);

        foreach (pkgname; pkgnames)
        {
            auto dep = packageNameToApkDependency(pkgname);
            toBeUpgraded ~= dep;

            const depPackage = apk_pkg_get_installed(dep.name);
            if (depPackage is null || depPackage.origin is null)
            {
                continue;
            }

            auto origin = depPackage.origin.ptr[0 .. depPackage.origin.len].to!string;
            // If the main package of the subpackage is installed, upgrade it as well
            if (origin != pkgname)
            {
                auto originNameBlob = apk_blob_t(origin.length, origin.toUTFz!(char*));
                auto originPackageName = apk_db_query_name(&this.db, originNameBlob);
                if (originPackageName !is null)
                {
                    if (apk_pkg_get_installed(originPackageName) !is null)
                    {
                        auto originDep = packageNameToApkDependency(origin);
                        toBeUpgraded ~= originDep;
                    }
                }
            }
        }

        foreach (dep; toBeUpgraded)
        {
            apk_solver_set_name_flags(dep.name, solverFlags, 0);
        }

        const auto solverErrorCount = apk_solver_commit(&this.db, 0, this.db.world);
        enforce!ApkDatabaseCommitException(solverErrorCount == 0,
                /* Translators: Do not translate 'apk add -u %s', it's the command the user should run */
                format(ngettext("Failed to upgrade package %s! Please run 'apk add -u %s' for more information.",
                    "Failed to upgrade packages %s! Please run 'apk add -u %s' for more information.",
                    cast(uint) solverErrorCount), apkd.functions.pkgnamesArrayToList(pkgnames),
                    apkd.functions.pkgnamesArrayToList(pkgnames)));

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
        apk_dependency_array* worldCopy;
        scope (exit)
        {
            apkd.functions.apk_dependency_array_free(&worldCopy);
        }
        apkd.functions.apk_dependency_array_copy(&worldCopy, this.db.world);

        foreach (ref pkgname; pkgnames)
        {
            auto dep = packageNameToApkDependency(pkgname);

            apk_deps_add(&worldCopy, dep);
            apk_solver_set_name_flags(dep.name, solverFlags, solverFlags);
        }

        const auto solverCommitErrorCount = apk_solver_commit(&this.db, solverFlags, worldCopy);
        enforce!ApkDatabaseCommitException(solverCommitErrorCount == 0,
                /* Translators: Do not translate 'apk add', it's the command the user should run */
                format(ngettext("Failed to add package %s! Please run 'apk add %s' for more information.",
                    "Failed to add packages %s! Please run 'apk add %s' for more information",
                    cast(uint) pkgnames.length), apkd.functions.pkgnamesArrayToList(pkgnames),
                    apkd.functions.pkgnamesArrayToList(pkgnames)));
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
    void deletePackages(string[] pkgnames, ushort solverFlags = 0)
    {
        apk_dependency_array* worldCopy;
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
        foreach (ref pkgname; pkgnames)
        {
            *apkd.functions.apk_string_array_add(&pkgnameArr) = pkgname.toUTFz!(char*);
            apk_deps_del(&worldCopy, packageNameToApkDependency(pkgname).name);
        }

        const auto solverErrorCount = apk_solver_solve(&this.db, solverFlags,
                worldCopy, &changeset);
        enforce!ApkSolverException(solverErrorCount == 0,
                /* Translators: Do not translate 'apk upgrade -a', it's the command the user should run */
                format(ngettext("Failed to delete package %s! Please run 'apk del %s' for more information.",
                    "Failed to delete packages %s! Please run 'apk del %s' for more information",
                    cast(uint) pkgnames.length), apkd.functions.pkgnamesArrayToList(pkgnames),
                    apkd.functions.pkgnamesArrayToList(pkgnames)));

        foreach (ref change; changeset.changes.item)
        {
            if (change.new_pkg !is null)
            {
                change.new_pkg.marked = 1;
            }
        }

        string[] dependants;
        apk_name_foreach_matching(&this.db, pkgnameArr,
                apk_foreach_genid() | APK_FOREACH_MARKED | APK_DEP_SATISFIES,
                &getNotDeletedPackageReason, &dependants);
        if (!dependants.empty())
        {
            throw new ApkCantDeletedRequiredPackage(format(
                    ngettext("package %s still required by the following packages: %s",
                    "packages %s still required by the following packages: %s",
                    cast(uint) pkgnames.length),
                    apkd.functions.pkgnamesArrayToList(pkgnames),
                    apkd.functions.pkgnamesArrayToList(dependants)));
        }

        const auto solverCommitErrorCount = apk_solver_commit_changeset(&this.db,
                &changeset, worldCopy);
        enforce!ApkDatabaseCommitException(solverCommitErrorCount == 0,
                /* Translators: Do not translate 'apk del', it's the command the user should run */
                format(ngettext("Failed to delete package %s! Please run 'apk del %s' for more information.",
                    "Failed to delete packages %s! Please run 'apk del %s' for more information",
                    cast(uint) pkgnames.length), apkd.functions.pkgnamesArrayToList(pkgnames),
                    apkd.functions.pkgnamesArrayToList(pkgnames)));

    }

    /**
    * Get a list of all packages that are installed.
    *
    * Returns: An array of all installed packages.
    */
    ApkPackage[] listInstalledPackages()
    {
        import apkd.functions : container_of;

        apk_installed_package* installedPackage;
        ApkPackage[] ret;
        ret.reserve(this.db.installed.stats.packages);// dfmt off
        for(
            installedPackage = (&this.db.installed.packages).next.container_of!(apk_installed_package, "installed_pkgs_list");
            &installedPackage.installed_pkgs_list != &this.db.installed.packages;
            installedPackage = installedPackage.installed_pkgs_list.next.container_of!(apk_installed_package, "installed_pkgs_list"))
        {
            ret ~= ApkPackage(installedPackage.pkg, true);
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
        apkPackages.reserve(this.db.available.packages.num_items);
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
        return ApkPackage(pkg, true);
    }

    /**
    * Reads all repositories from repoFilePath.
    *
    * Params:
    *   repoFilePath = File path to the repository file.
    *
    * Throws:
    *   ErrnoException if the file couldn't be opened or we can't read from it.
    */
    static ApkRepository[] getRepositories(string repoFilePath = "/etc/apk/repositories")
    {
        ApkRepository[] repos;
        auto repoFile = new File(repoFilePath, "r");

        foreach (ref line; repoFile.byLine())
        {
            if (!line.strip().empty())
            {
                repos ~= ApkRepository(repoFilePath, line.replace("#", "")
                        .strip().to!string, !line.strip().startsWith("#"));
            }
        }

        return repos;
    }

    /**
    * Sets the repositories in repoFilePath.
    *
    * Params:
    *   repos = The repositories that should be set in the repoFile.
    *   repoFilePath = File path to the repository file.
    *
    * Throws:
    *   ErrnoException if the file couldn't be opened or writing to it fails.
    */
    static void setRepositories(ApkRepository[] repos, string repoFilePath = "/etc/apk/repositories")
    {
        string line = "";
        auto repoFile = new File(repoFilePath, "w");

        foreach (ref repo; repos)
        {
            if (!repo.enabled)
            {
                line ~= "#";
            }
            line ~= repo.url ~ "\n";
        }
        repoFile.write(line);
        repoFile.flush();
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
            throw new ApkRepoUpdateException(format(gettext("Fetching repository %s failed due to error '%s'!"),
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
    apk_dependency* packageNameToApkDependency(string pkgname)
    {
        auto apk_dependency = new apk_dependency;
        apk_blob_t blob = apk_blob_t(pkgname.length, toUTFz!(char*)(pkgname));
        apk_blob_pull_dep(&blob, &this.db, apk_dependency);
        enforce!BadDependencyFormatException(!(blob.ptr is null || blob.len > 0), format(gettext(
                "'%s' is not a correctly formated world dependency, the format should be: name(@tag)([<>~=]version)"),
                pkgname));
        enforce!NoSuchPackageFoundException(apk_dependency !is null,
                format(gettext("Couldn't find package %s"), pkgname));
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
        /* Translators: repository tags are used for pinning packages to a specific repo: https://wiki.alpinelinux.org/wiki/Alpine_Linux_package_management#Repository_pinning*/
        const errMsg = gettext("Missing repository tags; can't continue the upgrade!");
        enforce!ApkBrokenWorldException(apk_db_check_world(&this.db, this.db.world) == 0, errMsg);
        const auto solverSolveRes = apk_solver_solve(&this.db,
                APK_SOLVERF_UPGRADE | solverFlags, this.db.world, &changeset);
        enforce!ApkSolverException(solverSolveRes == 0,
                /* Translators: Do not translate 'apk upgrade -a -s', it's the command the user should run */
                gettext(
                    "Failed to calculate upgrade changeset! Please run 'apk upgrade -a -s' for more information."));
        return changeset;
    }

    struct NotDeletedReasonContext
    {
        apk_name* name;
        string[]* notRemovedDue;
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
        auto pkgname = pkg.name.name.to!string;
        auto notRemovedDue = notDeletedReasonContext.notRemovedDue;
        if (pkgname != notDeletedReasonContext.name.name.to!string
                && !(*notRemovedDue).canFind(pkgname))
        {
            *notRemovedDue ~= pkgname;
        }

        foreachReverseDependency(pkg, true, true, false, &addNotDeletedPackage, ctx);
        foreach (ref dep; pkg.install_if.item)
        {
            foreach (ref provider; dep.name.providers.item)
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
        assert(cast(string[]*) ctx,
                "Casting to the expected type of our context failed! This is a bug.");
    }
    do
    {
        auto notRemovedDue = cast(string[]*) ctx;
        auto notDeletedReasonContext = NotDeletedReasonContext(name, notRemovedDue,
                apk_foreach_genid() | APK_FOREACH_MARKED | APK_DEP_SATISFIES);
        foreach (ref provider; name.providers.item)
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
            bool installed, bool, reverseDepFunc cb, void* ctx) nothrow
    {
        foreach (ref reverseDep; pkg.name.rdepends.item)
        {
            foreach (ref depPkg; reverseDep.providers.item)
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
        apk_db_init(&this.db);
        const auto res = apk_db_open(&this.db, &this.dbOptions);
        enforce!ApkDatabaseOpenException(res == 0,
                format(gettext("Failed to open apk database due to error '%s'"),
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
