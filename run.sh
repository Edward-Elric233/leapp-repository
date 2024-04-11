#!/usr/bin/env bash
sed -i '$ a\fs.file-max = 16005535' /etc/sysctl.conf
sysctl -p
dnf remove -y glibmm24-2.56.0-2.oc8.x86_64 crda-3.18_2020.04.29-1.oc8.noarch redhat-rpm-config-131-1.oc8.noarch
ls rpm/*.rpm | xargs dnf install -y
nohup sh -c "ulimit -n 102400; leapp preupgrade" > /var/log/leapp/leapp-upgrade-stdout.log 2>&1 &