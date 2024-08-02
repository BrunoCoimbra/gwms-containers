#!/bin/bash

# SPDX-FileCopyrightText: 2020 Fermi Research Alliance, LLC
# SPDX-License-Identifier: Apache-2.0

help_msg() {
    cat << EOF
$0 [options] 
Link a GlideinWMS RPM installation to a Git repository
  -h       print this message
  -v       verbose mode
  -d DIR   GlideinWMS directory (GWMS_DIR, Default: /opt/gwms). The repository will be in its ./glideinwms subdirectory
  -p PYVER Python version e.g. 3.9, 3.6, auto (Default: auto. Detect the highest version installed in /usr/lib/python*)
  -a       set up fActory
  -r       set up fRontend
EOF
}

GWMS_DIR=/opt/gwms
PYVER="auto"
while getopts "hd:p:var" option
do
  case "${option}"
    in
    h) help_msg; exit 0;;
    v) VERBOSE=yes;;
    d) GWMS_DIR=${OPTARG%/};;
    p) PYVER=$OPTARG;;
    a) IS_FACTORY=yes;;
    r) IS_FRONTEND=yes;;
    *) echo "ERROR: Invalid option"; help_msg; exit 1;;
  esac
done

if [[ "${PYVER}" = auto ]]; then
    PYVER="$(ls -d /usr/lib/python3* | tail -n1)"
    PYVER=${PYVER#/usr/lib/python}
    [[ -n "$VERBOSE" ]] && echo "PYVER auto. Detected and using Python $PYVER."
fi

if [ ! -d "/usr/lib/python${PYVER}/site-packages/glideinwms" ]; then
    echo "ERROR: GlideinWMS appears not installed (/usr/lib/python${PYVER}/site-packages/glideinwms is missing)"
    exit 1
fi
if ! mkdir -p "$GWMS_DIR"; then
    echo "ERROR: Unable to create the code directory '$GWMS_DIR'"
    exit 1
fi
GWMS_SRC_DIR="$GWMS_DIR"/glideinwms
if [[ ! "$(ls -A "$GWMS_SRC_DIR" 2>/dev/null)" ]]; then
    git clone https://github.com/glideinWMS/glideinwms.git "$GWMS_SRC_DIR"
fi

[[ ! "$(ls -A "$GWMS_SRC_DIR" 2>/dev/null)" ]] && { echo "Failed to clone GlideinWMS Git repository. Unable to link it."; exit 1; } || true

if [[ -L /usr/lib/python${PYVER}/site-packages/glideinwms ]]; then
    if [[ "$(cd -P "/usr/lib/python${PYVER}/site-packages/glideinwms" && pwd)" = "$(cd -P "$GWMS_SRC_DIR" && pwd)" ]]
    then
        echo "GlideinWMS already using the repository in $GWMS_SRC_DIR. Aborting the new Git setup"
        exit 0
    else
        echo "WARNING: Linking an installation already pointing to a different Git repository. Continuing"
    fi
fi

# mv to *_rpm instead of rm -rf
[[ -n "$VERBOSE" ]] && echo "Linking GlideinWMS library to repository in $GWMS_SRC_DIR" || true
mv /usr/lib/python${PYVER}/site-packages/glideinwms /usr/lib/python${PYVER}/site-packages/glideinwms_rpm
ln -s "$GWMS_SRC_DIR" /usr/lib/python${PYVER}/site-packages/glideinwms
if [[ -n "$IS_FACTORY" ]]; then
    [[ -n "$VERBOSE" ]] && echo "Linking Factory components to Git" || true
    mv /var/lib/gwms-factory/creation /var/lib/gwms-factory/creation_rpm
    mv /var/lib/gwms-factory/web-base /var/lib/gwms-factory/web-base_rpm
    ln -s "$GWMS_SRC_DIR"/creation /var/lib/gwms-factory/creation
    ln -s "$GWMS_SRC_DIR"/creation/web_base /var/lib/gwms-factory/web-base
fi
if [[ -n "$IS_FRONTEND" ]]; then
    [[ -n "$VERBOSE" ]] && echo "Linking Frontend components to Git" || true
    mv /var/lib/gwms-frontend/creation /var/lib/gwms-frontend/creation_rpm
    mv /var/lib/gwms-frontend/web-base /var/lib/gwms-frontend/web-base_rpm
    ln -s "$GWMS_SRC_DIR"/creation /var/lib/gwms-frontend/creation
    ln -s "$GWMS_SRC_DIR"/creation/web_base /var/lib/gwms-frontend/web-base
fi

# Remove $1 and replace with a soft link to $2/$1 (or $2/$3 if $3 is provided)
replace() {
    local src_name="$1"
    [[ -n "$3" ]] && src_name="$3" || true
    rm -f "$1"
    ln -s "$2/$src_name" "$1"
}

pushd /usr/sbin >/dev/null || { echo "ERROR: /usr/sbin not found"; exit 1; }

if [[ -n "$IS_FACTORY" ]]; then
    for i in \
    checkFactory.py glideFactoryEntryGroup.py glideFactoryEntry.py \
    glideFactory.py manageFactoryDowntimes.py stopFactory.py
    do
        rm -f ${i}*
        ln -s "$GWMS_SRC_DIR"/factory/${i} ${i}
        ln -s "$GWMS_SRC_DIR"/factory/${i}o ${i}o
        ln -s "$GWMS_SRC_DIR"/factory/${i}c ${i}c
    done
    
    for i in \
    clone_glidein info_glidein reconfig_glidein
    do
        replace ${i} "$GWMS_SRC_DIR"/creation
    done
fi
if [[ -n "$IS_FRONTEND" ]]; then
    for i in \
    checkFrontend glideinFrontend stopFrontend
    do
        replace "$i" "$GWMS_SRC_DIR"/frontend "${i}.py"
    done
    
    for i in \
    glideinFrontendElement.py manageFrontendDowntimes.py
    do
        replace "$i" "$GWMS_SRC_DIR"/frontend
    done
    
    for i in \
    reconfig_frontend
    do
        replace "${i}" "$GWMS_SRC_DIR"/creation
    done
fi

for i in \
glidecondor_createSecCol glidecondor_addDN glidecondor_createSecSched
do
    replace "${i}" "$GWMS_SRC_DIR"/install
done

popd >/dev/null

pushd /usr/bin >/dev/null || { echo "ERROR: /usr/bin not found"; exit 1; }

for i in \
glidein_cat glidein_gdb glidein_interactive glidein_ls glidein_ps \
glidein_status glidein_top
do
    replace "${i}" "$GWMS_SRC_DIR"/tools "${i}.py"
done

popd >/dev/null
