#!/bin/bash

fingerprints=$(ssh-keygen -lf <(ssh-keyscan $1 2>/dev/null))

for fingerprint in $fingerprints
do
        if [ "$fingerprint" == "$2" ]
        then
                exit 0
        fi
done

exit 1