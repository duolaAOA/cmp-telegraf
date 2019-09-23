#!/bin/sh

INFLUX_DB="telegraf"
INFLUX_HOST="http://influxdb:8086"

USAGE=" Usage: $0 [-h] [-k] -m <MACHINE> [-p <PASSWORD>] [-s <HOST>] [-d <DB>]

Run Telegraf in a Docker container

Options:
    -h             Show this help message
    -k             Kill/stop a running container and exit
    -u <USERNAME>  The Username to be used for authentication
    -p <PASSWORD>  The Password to be used for authentication
    -m <MACHINE>   The UUID of the monitored machine
    -s <HOST>      The InfluxDB host to send data to. Defaults to $INFLUX_HOST
    -d <DB>        The database to write metrics to.  Defaults to $INFLUX_DB
"

set -e

while getopts ":hkp:m:s:d:" opt; do
    case "$opt" in
        h)
            echo "$USAGE"
            exit
            ;;
        k)
            KILL=1
            ;;
        u)
            MACHINE_USER=$OPTARG
            ;;
        p)
            MACHINE_PASS=$OPTARG
            ;;
        m)
            MACHINE_UUID=$OPTARG
            ;;
        s)
            INFLUX_HOST=$OPTARG
            ;;
        d)
            INFLUX_DB=$OPTARG
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            echo "$USAGE" >&2
            exit 1
    esac
done

exists() { command -v $@ > /dev/null 2>&1; }

fetch() {
    if exists wget; then
        local cmd="wget"
    elif exists curl; then
        local cmd="curl -O -sSL"
    else
        echo "Failed to locate wget/cURL" >&2
        echo "Unable to download $@" >&2
        exit 127
    fi
    $cmd $@
}

if ! exists docker; then
    echo "Docker not found. Try:" >&2
    echo "wget -qO- https://get.docker.com/ | sudo sh" >&2
    exit 127
fi

[ -d /opt/cmp/ ] || mkdir -p /opt/cmp/
[ -f /opt/cmp/telegraf.conf ] && rm -f /opt/cmp/telegraf.conf

echo "Switching to directory /opt/cmp/" >&2 && cd /opt/cmp/

containers=$( docker ps --format="{{ .Names }}" )
echo $containers | grep cmp-telegraf && docker stop cmp-telegraf

if [ -n "$KILL" ]; then
    exit 0
fi

SCHEME=$( echo "$INFLUX_HOST" | cut -s -d : -f 1 )
HOST=$( echo "$INFLUX_HOST" | cut -s -d : -f 2 )
PORT=$( echo "$INFLUX_HOST" | cut -s -d : -f 3 )

if [ -z "$SCHEME" ] || [ -z "$HOST" ] || [ -z "$PORT" ]; then
    echo >&2
    echo >&2
    echo "Invalid destination endpoint: $SCHEME://$HOST:$PORT" >&2
    echo >&2
    echo >&2
    echo "$USAGE" >&2
    exit 1
fi

if [ -z "$MACHINE_UUID" ]; then
    echo >&2
    echo >&2
    echo "Required argument missing" >&2
    echo >&2
    echo >&2
    echo "$USAGE" >&2
    exit 1
fi

fetch https://cmp.knownsec.com/api/v1/telegraf/telegraf.conf

docker run -d --name cmp-telegraf \
    -v /opt/cmp/telegraf.conf:/etc/telegraf/telegraf.conf:ro \
    -e TELEGRAF_DB=$INFLUX_DB \
    -e TELEGRAF_HOST=$INFLUX_HOST \
    -e TELEGRAF_MACHINE=$MACHINE_UUID \
    -e TELEGRAF_USERNAME="client" \
    -e TELEGRAF_PASSWORD=$MACHINE_PASS \
    telegraf:1.2.1
