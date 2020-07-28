module apkd_dbus_server.OperationErrorTranslator;

import apkd_common.gettext;
import std.conv;

class OperationErrorTranslator
{
    this(string value)
    {
        this.value = value.to!Enum;
    }

    enum Enum
    {
        addPackages,
        deletePackages,
        getAll,
        getAllowUntrustedRepos,
        getRoot,
        listAvailablePackages,
        listInstalledPackages,
        listUpgradablePackages,
        updateRepositories,
        upgradeAllPackages,
        upgradePackages,
        searchFileOwner,
        searchPackagenames,
        setAllowUntrustedRepos,
        setRoot,
    }

    string translateOperationError(uint nPackages = 0) const
    {
        final switch (this.value) with (Enum)
        {
        case addPackages:
            return ngettext("Couldn't add package due to error %s",
                    "Couldn't add packages due to error %s", nPackages);
        case deletePackages:
            return ngettext("Couldn't delete package due to error %s",
                    "Couldn't delete packages due to error %s", nPackages);
        case getAll:
            return gettext("Couldn't get the value of all DBus-properties due to error %s");
        case getAllowUntrustedRepos:
            /* Translators: Do not translate "allowUntrustedRepos", it's the name of the property */
            return gettext(
                    "Couldn't get the value of DBus-property “allowUntrustedRepos“ due to error %s");
        case getRoot:
            /* Translators: Do not translate "root", it's the name of the property */
            return gettext("Couldn't get the value of DBus-property “root“ due to error %s");
        case listAvailablePackages:
            return gettext("Couldn't list available packages due to error %s");
        case listInstalledPackages:
            return gettext("Couldn't list installed packages due to error %s");
        case listUpgradablePackages:
            return gettext("Couldn't list upgradable packages due to error %s");
        case updateRepositories:
            return gettext("Couldn't update repositories due to error %s");
        case upgradeAllPackages:
            return gettext("Couldn't upgrade all packages due to error %s");
        case upgradePackages:
            return ngettext("Couldn't upgrade package due to error %s",
                    "Couldn't upgrade packages due to error %s", nPackages);
        case searchFileOwner:
            return gettext("Couldn't search for owner of file due to error %s");
        case searchPackagenames:
            return gettext("Couldn't search for packages due to error %s");
        case setAllowUntrustedRepos:
            /* Translators: Do not translate "allowUntrustedRepos", it's the name of the property */
            return gettext(
                    "Couldn't set the value of DBus-property “allowUntrustedRepos“ due to error %s");
        case setRoot:
            /* Translators: Do not translate "root", it's the name of the property */
            return gettext("Couldn't set the value of DBus-property “root“ due to error %s");
        }
    }

    string translateAuthError(uint nPackages = 0) const
    {
        final switch (this.value) with (Enum)
        {
        case addPackages:
            return ngettext("Authorization for adding a package failed due to error %s",
                    "Authorization for adding packages failed due to error %s", nPackages);
        case deletePackages:
            return ngettext("Authorization for deleting a package failed due to error %s",
                    "Authorization for deleting packages failed due to error %s", nPackages);
        case getAll:
            return gettext(
                    "Authorization for getting the value of all DBus-properties failed due to error %s");
        case getAllowUntrustedRepos:
            /* Translators: Do not translate "allowUntrustedRepos", it's the name of the property */
            return gettext(
                    "Authorization for getting the value of DBus-property “allowUntrustedRepos“ failed due to error %s");
        case getRoot:
            /* Translators: Do not translate "root", it's the name of the property */
            return gettext(
                    "Authorization for getting the value of DBus-property “root“ failed due to error %s");
        case listAvailablePackages:
            return gettext("Authorization for listing available packages failed due to error %s");
        case listInstalledPackages:
            return gettext("Authorization for listing installed packages failed due to error %s");
        case listUpgradablePackages:
            return gettext("Authorization for listing upgradable packages failed due to error %s");
        case updateRepositories:
            return gettext("Authorization for updating repositories failed due to error %s");
        case upgradeAllPackages:
            return gettext("Authorization for upgrading all packages failed due to error %s");
        case upgradePackages:
            return ngettext("Authorization for upgrading a package failed due to error %s",
                    "Authorization for upgrading packages failed due to error %s", nPackages);
        case searchFileOwner:
            return gettext(
                    "Authorization for searching for the owner of file failed due to error %s");
        case searchPackagenames:
            return gettext("Authorization for searching for packages failed due to error %s");
        case setAllowUntrustedRepos:
            /* Translators: Do not translate "allowUntrustedRepos", it's the name of the property */
            return gettext(
                    "Authorization for setting the value of DBus-property “allowUntrustedRepos“ failed due to error %s");
        case setRoot:
            /* Translators: Do not translate "root", it's the name of the property */
            return gettext(
                    "Authorization for setting the value of DBus-property “root“ failed due to error %s");
        }
    }

    private Enum value;
}
