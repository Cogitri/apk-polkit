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

module apkd_dbus_server.Polkit;

import gio.Cancellable;
import glib.MainLoop;
import polkit.Authority;
import polkit.Details;
import polkit.SystemBusName;
import std.experimental.logger;

/**
* Query the polkit authority if a certain DBus sender is permitted to
* execute a certain action.
*
* Params:
*   action  =   The ID of the polkit action that should be checked
*   sender  =   The unique DBus sender ID of who is trying to execute
*               the action.
*
* Returns: True if the authorization succeeded.
*/
bool queryPolkitAuth(string action, string sender)
{
    auto authority = Authority.getSync(null);
    auto systemBusName = new SystemBusName(sender);
    auto subject = systemBusName.getProcessSync(null);
    //auto callbackData = PolkitCallbackData(operation, origThreadId);
    auto details = new Details();
    details.insert("polkit.gettext_domain", "apk-polkit");

    auto polkitResult = authority.checkAuthorizationSync(subject, action,
            details, CheckAuthorizationFlags.ALLOW_USER_INTERACTION, null);

    auto authorized = false;

    if (polkitResult.getIsAuthorized)
    {
        authorized = true;
        infof("Polkit authorized operation %s", action);
    }
    else if (polkitResult.getIsChallenge())
    {
        infof("Awaiting Polkit challenge for operation %s.", action);
    }
    else
    {
        warningf("Polkit authorization attempted, but failed for operation %s.", action);
    }

    return authorized;
}

/* Switch to this once we can do async dbus returns
struct PolkitCallbackData
{
    string action;
    ulong origThreadId;
}

void checkPolkitAuthorizedCallBack(Authority authority, GAsyncResult* res, void* userData)
{
    auto callbackData = cast(PolkitCallbackData*) userData;
    auto polkitResult = authority.checkAuthorizationFinish(res);
    auto authorized = false;

    if (polkitResult.getIsAuthorized)
    {
        authorized = true;
        info("Polkit authorized operation %s", action);
    }
    else if (polkitResult.getIsChallenge())
    {
        info("Awaiting Polkit challenge for operation %s.", action);
    }
    else
    {
        warning("Polkit authorization attempted, but failed for operation %s.",
                action);
    }

    send(callbackData.origThreadId, authorized);
}
*/
