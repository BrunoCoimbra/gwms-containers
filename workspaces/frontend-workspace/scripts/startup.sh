#!/bin/bash

# SPDX-FileCopyrightText: 2020 Fermi Research Alliance, LLC
# SPDX-License-Identifier: Apache-2.0

GWMS_DIR=/opt/gwms
FULL_STARTUP=true
DO_LINK_GIT=
GWMS_REPO=
# Leaving unchanged. Default branch after cloning is master
GWMS_REPO_REF=
help_msg() {
    cat << EOF
$0 [options] 
  -h       print this message
  -v       verbose mode
  -g       do Git setup (default for regular startup)
  -G       skip Git setup (default for refresh)
  -c REF   Checkout REF in the GlideinWMS Git repository (Default: no checkout, leave the default/existing reference)
  -u URL   Git repository URL (See link-git.sh for Default)
  -r       refresh only
EOF
}

while getopts "hvgGc:u:r" option
do
  case "${option}"
    in
    h) help_msg; exit 0;;
    v) VERBOSE=yes;;
    g) DO_LINK_GIT=true;;
    G) DO_LINK_GIT=false;;
    c) GWMS_REPO_REF="-c ${OPTARG}";;
    u) GWMS_REPO="-u ${OPTARG}";;
    r) FULL_STARTUP=false;;
    *) echo "ERROR: Invalid option"; help_msg; exit 1;;
  esac
done

[[ -z "$DO_LINK_GIT" ]] && DO_LINK_GIT=$FULL_STARTUP || true

if $FULL_STARTUP; then
    # First time only
    [[ -n "$VERBOSE" ]] && echo "Full startup" || true
    bash /opt/scripts/create-host-certificate.sh -d "$GWMS_DIR"/secrets
    # shellcheck disable=SC2086   # Options are unquoted to allow globbing
    $DO_LINK_GIT && bash /opt/scripts/link-git.sh -r -d "$GWMS_DIR" $GWMS_REPO $GWMS_REPO_REF || true
    bash /opt/scripts/create-idtokens.sh -r
    systemctl start httpd
    systemctl start condor
else
    # Other times only (refresh) 
    [[ -n "$VERBOSE" ]] && echo "Refresh only" || true
    systemctl stop gwms-frontend
    # shellcheck disable=SC2086   # Options are unquoted to allow globbing
    $DO_LINK_GIT && bash /opt/scripts/link-git.sh -r -d "$GWMS_DIR" $GWMS_REPO $GWMS_REPO_REF || true
    systemctl restart condor  # in case the configuration changes
fi
# All the times
# Always recreate the scitoken (expires quickly, OK to have a new one)
bash /opt/scripts/create-scitoken.sh
gwms-frontend upgrade
systemctl start gwms-frontend
