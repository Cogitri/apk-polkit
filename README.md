# apk-polkit
[![Gitlab CI status](https://gitlab.alpinelinux.org/Cogitri/apk-polkit/badges/master/pipeline.svg)](https://gitlab.alpineliux.org/Cogitri/apk-polkit/commits/master)

apk-polkit exposes a DBus API for libapk, the library used by APK, the Alpine Package Keeper.
It is intended to be used by software centres like GNOME Software.

apk-polkit works by running as a daemon with root permissions. It authenticates
users via polkit and if the authentication suceeds, it executes the operation
the user instructed it to do (e.g. install packages, update packages, ...)

## Building

Apk-polkit has a few dependencies:

* [glibd](https://github.com/gtkd-developers/GlibD/)
* [polkit-d](https://gitlab.alpinelinux.org/Cogitri/polkit-d/)
* [apk-tools-d](https://gitlab.alpinelinux.org/Cogitri/apk-toolsd/)
* A functional D compiler.

Once these are installed, building and installing it should be as easy as:

```sh
meson build
ninja -C build test
ninja -C build install
```
