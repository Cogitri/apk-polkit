#!/bin/sh
#
# Test runner for running apkd_dbus_client tests with the right environment

# start a fake system bus
eval `dbus-launch`
export DBUS_SYSTEM_BUS_ADDRESS=$DBUS_SESSION_BUS_ADDRESS

# start mocking
python3 -m dbusmock --template $TEMPLATE_PATH 1>&2 &

# Wait for DBusmock to turn up
sleep 1

"$@"
