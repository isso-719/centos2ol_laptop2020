#!/bin/bash

# システムの前提をチェックする
# 実行済みチェック
rpm -qi oraclelinux-release > /dev/null
RET=$?
if [[ "${RET}" -eq 0 ]]; then
    echo "Oracle Linux へ移行済みのため、実行する必要はありません。"
    exit 0
fi

# CentOS かチェック
cat /etc/redhat-release | grep CentOS > /dev/null
RET=$?
if [[ "${RET}" -ne 0 ]]; then
    echo "CentOS でないので実行はできません。"
    exit 1
fi


# 移行前質問
echo "********************************************************"
echo "注意: 移行処理に失敗すると、この Linux 環境が壊れる可能性があります。"
echo "下記の質問に y もしくは N で回答してください。"
echo "********************************************************"
read -p "RAT からの案内手順に従い、VMware で VM のスナップショットを作成しましたか? y: はい, N: いいえ: " IS_SNAPSHOT
if [[ "${IS_SNAPSHOT}" != "y" ]]; then
    echo "VM のスナップショットを作成してから再度実行してください。"
    exit 1
fi

# Down 80 Mbps/s での実行時間 19m 59.684s
echo "********************************************************"
echo "移行には約 20 分かかります。時間に余裕がある時に移行してください。"
echo "また、約 2.0 GB の安定した通信を必要とします。"
echo "********************************************************"
read -p "RAT からの案内手順に従い、現在の環境は以上の要件を満たしていますか? y: はい, N: いいえ: " IS_SNAPSHOT
if [[ "${IS_SNAPSHOT}" != "y" ]]; then
    echo "環境を整えてから再度実行してください。"
    exit 1
fi


# 移行開始
echo "********************************************************"
echo "CentOS から OracleLinux へ移行を開始します。"
echo "移行中、デスクトップの壁紙が正常に映らなくなる場合があります。"
echo "********************************************************"

# centos2ol.sh の存在チェックと削除
cd
if [ -f centos2ol.sh ]; then rm centos2ol.sh -f; fi

# centos2ol.sh をダウンロード
wget https://raw.githubusercontent.com/oracle/centos2ol/main/centos2ol.sh

# centos2ol.sh の権限を設定
chmod 700 centos2ol.sh

# centos2ol.sh を実行
./centos2ol.sh -V -k

# ./centos2ol を削除
rm -f ./centos2ol.sh

# CentOS の不要なレポジトリ設定を削除
rm /etc/yum.repos.d/CentOS-* -f

# 問題のある module をリセット
dnf -y module reset virt

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
# dnf -y remove kernel-uek
# yes no | cp -ai /etc/yum.repos.d/oracle-linux-ol8.repo{,.default}
# dnf config-manager --disable ol8_UEKR6

# CentOS 由来パッケージの入れ替え・削除
dnf -y swap centos-indexhtml redhat-indexhtml --nobest

# dnf コマンドを実行時の競合を解消
# ディストリビューション固有のモジュールストリームを切り替える
sed -i -e 's|rhel8|ol8|g' /etc/dnf/modules.d/*.module

# dnf-rpmfusion リポジトリの追加 (priority=25)
dnf -y install https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
yes no | cp -ai /etc/yum.repos.d/rpmfusion-free-updates.repo{,.default}
dnf config-manager --disable rpmfusion-free-updates
dnf config-manager --setopt="rpmfusion-free-updates.priority=25" --save rpmfusion-free-updates

# epel,elrepo,rpmfusion-free-updates レポジトリを有効にしつつ、dnf update を実行
dnf -y --enablerepo=epel,elrepo,rpmfusion-free-updates update

# 移行完了
rpm -qi oraclelinux-release > /dev/null
RET=$?
echo "********************************************************"
if [[ "${RET}" -eq 0 ]]; then
    echo "移行が完了しました。"
    echo "エラーが表示されている場合は RAT までスクリーンショット等を添付して相談してください。"
    echo "reboot コマンドを実行して反映してください。"
else
    echo "Oracle Linux への移行に失敗しました。"
    echo "表示されているテキストメッセージをすべてコピーして RAT へ相談するか、"
    echo "Linux 上のデータはすべて消えますが、イメージを丸ごと差し替えて移行する方法を検討してください。"
    exit 1
fi
echo "********************************************************"


# Laptop2020-CentOS-To-OracleLinux.sh を削除
rm -f "${0}"
