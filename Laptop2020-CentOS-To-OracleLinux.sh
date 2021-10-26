#!/bin/sh

echo "********************************************************"
echo "CentOS から OracleLinux へ移行を開始します。"
echo "移行には時間がかかる場合があります。"
echo "********************************************************"

# centos2ol.sh をダウンロード
cd
wget https://raw.githubusercontent.com/oracle/centos2ol/main/centos2ol.sh

# centos2ol.sh の権限を設定
chmod 700 centos2ol.sh

# centos2ol.sh を実行
# -V オプションで最小限の RPM のみ Oracle Linux のものにする
./centos2ol.sh -V

# ./centos2ol を削除
rm -f ./centos2ol.sh

# CentOS の不要なレポジトリ設定を削除
rm /etc/yum.repos.d/CentOS-* -f

# dnf 公式リポジトリの優先度設定 (priority=10)
yes no | cp -ai /etc/yum.repos.d/oracle-linux-ol8.repo{,.default}
yes no | cp -ai /etc/yum.repos.d/uek-ol8.repo{,.default}
dnf config-manager --setopt="ol8_baseos_latest.priority=10" --save ol8_baseos_latest
dnf config-manager --setopt="ol8_appstream.priority=10" --save ol8_appstream
dnf config-manager --setopt="ol8_UEKR6.priority=10" --save ol8_UEKR6

# dnf ol8_codeready_builder 公式リポジトリの有効化 (priority=15)
yes no | cp -ai /etc/yum.repos.d/oracle-linux-ol8.repo{,.default}
dnf config-manager --enable ol8_codeready_builder
dnf config-manager --setopt="ol8_codeready_builder.priority=15" --save ol8_codeready_builder

# oracle-epel-release-el8 の epel-release への入れ替え
dnf -y remove oracle-epel-release-el8
rm /etc/yum.repos.d/epel.repo* -f
dnf -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm

# 通常時 EPEL のリポジトリを使わないようにする
yes no | cp -ai /etc/yum.repos.d/epel.repo{,.default}
yes no | cp -ai /etc/yum.repos.d/epel-modular.repo{,.default}
dnf config-manager --disable epel
dnf config-manager --setopt="epel.priority=20" --save epel
dnf config-manager --disable epel-modular
dnf config-manager --setopt="epel-modular.priority=20" --save epel-modular

# Unbreakable Enterprise Kernel(UEK) の削除と無効化
dnf -y remove kernel-uek
yes no | cp -ai /etc/yum.repos.d/oracle-linux-ol8.repo{,.default}
dnf config-manager --disable ol8_UEKR6

# CentOS 由来パッケージの入れ替え・削除
rpm -qa | grep centos
dnf -y swap centos-logos-httpd oracle-logos-httpd
dnf -y remove centos-gpg-keys

# Laptop2020-CentOS-To-OracleLinux.sh を削除
rm -f ./Laptop2020-CentOS-To-OracleLinux.sh

# 移行完了
echo "********************************************************"
echo "移行が完了しました。"
echo "10秒後に再起動を行います...。"
echo "********************************************************"

# 遅延
sleep 10

# すべての反映
reboot
