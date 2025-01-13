#!/bin/bash

# SPDX-FileCopyrightText: 2020 Fermi Research Alliance, LLC
# SPDX-License-Identifier: Apache-2.0

GWMS_DIR=/opt/gwms

bash /opt/scripts/create-host-certificate.sh -d "$GWMS_DIR"/secrets
systemctl start httpd
