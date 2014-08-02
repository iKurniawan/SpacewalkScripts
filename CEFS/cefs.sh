#!/bin/bash
## Configuration start ##
MAILTO=root
CHANNELS="centos6-x86_64 centos6-x86_64-updates centos6-x86_64-contrib centos6-x86_64-extras centos6-x86_64-centosplus epel6-centos6-x86_64"
SWSERVER="localhost"
LOCKFILE="/var/run/spacewalk_sync.lock"
## Configuration end ##

## Spacewalk Auth = spacewalk-auth.conf file
. ./spacewalk-auth.conf

## Repository sync
reposync()
    {
        if [ -e "$LOCKFILE" ]; then
            echo "[!] Another instance already running. Aborting."
            exit 1
            else
                touch "$LOCKFILE"
        fi
        trap "rm ${LOCKFILE}" EXIT

        for chanlabel in $CHANNELS;
        do spacewalk-repo-sync -c $chanlabel;
        done
    }

## Download errata file and checksums
erratasync()
    {
        wget -N http://cefs.steve-meier.de/errata.latest.xml 1>/dev/null 2>&1
        wget -N http://cefs.steve-meier.de/errata.latest.md5 1>/dev/null 2>&1
        wget -N http://www.redhat.com/security/data/oval/com.redhat.rhsa-all.xml.bz2 1>/dev/null 2>&1
        bunzip2 -f com.redhat.rhsa-all.xml.bz2
        ## Integrity
        grep "errata.latest.xml$" errata.latest.md5 > myerrata.md5
        md5sum -c myerrata.md5 1>/dev/null 2>&1
        if [ "$?" == 0 ]; then
            ## ok - import errata
            ## . ./spacewalk-auth.conf
            ./errata-import.pl --server $SWSERVER --errata errata.latest.xml \
            --rhsa-oval=com.redhat.rhsa-all.xml --publish 1>/dev/null
            if [ "$?" != 0 ]; then
                echo "[?] It seems like there was a problem while publishing the most recent errata..."
                exit 1
            fi
            rm myerrata.md5
            else
                ## Errata information possibly invalid
                echo "[!] ERROR: md5 checksum mismatch, check download!"
                exit 1
        fi
    }

reposync
erratasync
