#!/bin/bash -e


mkdir -p "$1"/lib/apk/db

pushd "$1"/lib/apk/db

touch installed lock scripts.tar triggers

popd

apk --allow-untrusted -X "$2" add --root "$1" --initdb

for x in $(dirname "$0")/repo/*/APKBUILD; do
    cd ${x%/*}
    APK="apk --allow-untrusted" REPODEST="$2/../" abuild -r
done