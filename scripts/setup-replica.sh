#!/bin/bash
set -e

# Wait for the primary to be reachable
until pg_isready -h db-primary -U "$REPLICATION_USER"; do
    echo "Waiting for primary database..."
    sleep 2
done

RANDOM_SLEEP=$(shuf -i 1-5 -n 1)
echo "Staggering startup: sleeping for $RANDOM_SLEEP seconds..."
sleep $RANDOM_SLEEP

# If the data directory is empty, clone the primary
if [ ! -s "$PGDATA/PG_VERSION" ]; then
    echo "Cloning data into $PGDATA..."
    rm -rf "$PGDATA"/*
    # Note: We point -D to $PGDATA
    pg_basebackup -h db-primary -D "$PGDATA" -U replicator -vP -R -X stream
    chown -R postgres:postgres "$PGDATA"
    chmod 700 "$PGDATA"
fi

# Hand over to the original entrypoint
echo "Replica data is ready. Starting Postgres..."
exec docker-entrypoint.sh postgres