#!/bin/bash

tmpfile=$(mktemp /tmp/check-host-fingerprints.tmp.XXXXXX)
ssh-keyscan $1 2>/dev/null > $tmpfile
fingerprints=$(ssh-keygen -lf $tmpfile | awk '{print $2}')

for fingerprint in $fingerprints
do
        if [ "$fingerprint" == "$2" ];
        then
                exit 0
        fi
done

exit 1