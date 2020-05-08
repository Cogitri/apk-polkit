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

module apkd_common.globals;

immutable auto dbusInterfaceName = "dev.Cogitri.apkPolkit.Helper";
immutable auto dbusObjectPath = "/dev/Cogitri/apkPolkit/Helper";
immutable auto dbusBusName = "dev.Cogitri.apkPolkit.Helper";
immutable auto apkdVersion = "@APKD_VERSION@";
immutable auto localeDir = "@APKD_LOCALE_DIR@";
