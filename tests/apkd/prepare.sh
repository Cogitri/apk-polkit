#!/bin/bash -e

mkdir -p "$1"/lib/apk/db

pushd "$1"/lib/apk/db

touch installed lock scripts.tar triggers

popd

apk --allow-untrusted -X "$2"/repo add --root "$1" --initdb
abuild-keygen -anq

mkdir -p "$2"

cp -r $(dirname "$0")/repo "$2"/abuilds

cd "$2"

for x in abuilds/*/APKBUILD; do
    pushd ${x%/*}
    APK="apk --allow-untrusted --root $1" SUDO_APK="abuild-apk --root $1" REPODEST="$2" abuild -F clean unpack prepare build rootpkg update_abuildrepo_index
    popd
done
