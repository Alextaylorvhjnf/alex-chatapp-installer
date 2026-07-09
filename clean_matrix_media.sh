#!/bin/bash

CONTAINER="chatapp-synapse"

docker exec $CONTAINER find /data/media_store \
-type f \
-mtime +10 \
-delete

echo "$(date): Matrix media older than 10 days deleted"
