module apkd.functions;

import deimos.apk_toolsd.apk_defines;

/// Taken from apk_defines.h. It's only declared&defined in the
/// header, so it doesn't end up in libapk...
void list_init(list_head* list)
{
    list.next = list;
    list.prev = list;
}
