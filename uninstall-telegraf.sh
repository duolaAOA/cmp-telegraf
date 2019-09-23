#!/bin/sh

USAGE="Usage: $0 [-h]

Uninstall Telegraf

Options:
    -h             Show this help message
"

set -e

while getopts ":h" opt; do
    case "$opt" in
        h)
            echo "$USAGE"
            exit
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "$USAGE" >&2
            exit 1
    esac
done

echo >&2
echo "Removing Telegraf service" >&2

if which systemctl > /dev/null && [ "$(cat /proc/1/comm)" = "systemd" ]; then
    systemctl stop cmp-telegraf
    systemctl disable cmp-telegraf
    if [ -f /lib/systemd/system/cmp-telegraf.service ]; then
        rm -f /lib/systemd/system/cmp-telegraf.service
    else
        rm -f /usr/lib/systemd/system/cmp-telegraf.service
    fi
    systemctl daemon-reload
else
    /etc/init.d/cmp-telegraf stop
    if which update-rc.d > /dev/null; then
        update-rc.d -f cmp-telegraf remove
    else
        chkconfig --del cmp-telegraf
    fi
    rm -f /etc/init.d/cmp-telegraf
fi

echo >&2
echo "Removing Telegraf files from /opt/cmp/" >&2

cd /opt/cmp/ && rm -rf *telegraf*

echo >&2
echo "Telegraf uninstalled successfully!" >&2
echo >&2
