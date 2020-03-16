module apkd_dbus_server.Polkit;

import gio.Cancellable;
import glib.MainLoop;
import polkit.Authority;
import polkit.Details;
import polkit.SystemBusName;
import std.experimental.logger;

bool queryPolkitAuth(string action, string sender)
{
    auto authority = Authority.getSync(null);
    auto systemBusName = new SystemBusName(sender);
    auto subject = systemBusName.getProcessSync(null);
    //auto callbackData = PolkitCallbackData(operation, origThreadId);
    auto details = new Details();
    details.insert("polkit.gettext_domain", "apkd");

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
