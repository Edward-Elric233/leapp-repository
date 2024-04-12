#!/usr/bin/env bash

function leapp_upgrade {
    sed -i '$ a\fs.file-max = 16005535' /etc/sysctl.conf
    sysctl -p
    dnf remove -y glibmm24-2.56.0-2.oc8.x86_64 crda-3.18_2020.04.29-1.oc8.noarch redhat-rpm-config-131-1.oc8.noarch
    ls rpm/*.rpm | xargs dnf install -y

    rm /etc/leapp/repos.d/system_upgrade/common/actors/prepare4upgrade -rf
    mkdir /etc/leapp/repos.d/system_upgrade/common/actors/prepare4upgrade
    cat << EOF > /etc/leapp/repos.d/system_upgrade/common/actors/prepare4upgrade/actor.py
import errno
import os
import shutil
import subprocess
from datetime import datetime

from leapp import reporting
from leapp.actors import Actor
from leapp.libraries.stdlib import api, run
from leapp.reporting import create_report, Report
from leapp.tags import FirstBootPhaseTag, IPUWorkflowTag


class Prepare4Upgrade(Actor):
    """
    prepare upgrade for ts4
    """

    name = 'prepare_for_upgrade'
    consumes = ()
    produces = (Report,)
    tags = (FirstBootPhaseTag.After, IPUWorkflowTag)

    def process(self):
        command = 'systemctl start leapp_custom_upgrade.service'
        subprocess.Popen(command, shell=True)
EOF

    service_name="leapp_custom_upgrade.service"
    service_path="/etc/systemd/system/$service_name"
    script_path=$(cd $(dirname "$0") && pwd)/$(basename "$0")
    #echo "The script is located at: $script_path"

    cat <<EOF > $service_path
[Unit]
Description=Custom Leapp Upgrade Service

[Service]
Type=oneshot
ExecStart=/usr/bin/bash "$script_path"
TimeoutStartSec=infinity
StandardOutput=journal+console
EOF

    systemctl daemon-reload

    nohup sh -c "ulimit -n 102400; leapp upgrade --reboot" > /var/log/leapp/leapp-upgrade-stdout.log 2>&1 &
}

function leapp_upgrade_after {
    while true; do
        count=$(ps aux | grep leapp -c) #if there is no other leapp process, count will be 3
        if [ "$count" -gt 3 ]; then
            echo "More than one leapp process found. Waiting..."
            sleep 3
        else
            echo "One or no leapp process found. Exiting loop."
            break
        fi
    done

    systemctl start NetworkManager
    DEVICE=$(nmcli device status | grep ethernet | awk '{print $1}')
    nmcli device connect "$DEVICE"  #打开网络

    source /root/.leapp.env
    curl -X POST http://"$SERVER_IP":"$SERVER_PORT"/api/task/finish/"$TASK_ID" # 通知系统升级成功

    # 允许root登录
    sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    systemctl restart sshd
}

source /etc/os-release

if [[ $VERSION_ID =~ ^8 ]]; then
    leapp_upgrade
elif [[ $VERSION_ID =~ ^9 ]]; then
    leapp_upgrade_after
else
    echo "Unknown version"
fi