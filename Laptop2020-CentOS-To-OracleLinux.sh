#!/bin/bash
#
# Laptop2020 の CentOS 8 環境 EOL に伴う Oracle Linux 8 への移行スクリプトです。
#
# @author Kazuki Isogai (RAT)

# システムチェック
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
    exit 0
fi

# 移行前説明
echo "********************************************************"
echo "CentOS 8 から Oracle Linux 8 へ移行を開始します。"
echo "********************************************************"

# 移行前にスナップショット取っているのか質問
echo "********************************************************"
echo "注意: 移行処理に失敗すると、この Linux 環境が壊れる可能性があります。"
echo "下記の質問に y もしくは N で回答してください。"
echo "********************************************************"
read -p "RAT からの案内手順に従い、VMware で VM のスナップショットを作成しましたか? y: はい, N: いいえ: " IS_SNAPSHOT
if [[ "${IS_SNAPSHOT}" != "y" ]]; then
    echo "VM のスナップショットを作成してから再度実行してください。"
    exit 1
fi

# 実行環境についての注意と質問
# Down 80 Mbps での実行時間 7m 16.019s
echo "********************************************************"
echo "移行には約 8 分かかります。時間に余裕がある時に移行してください。"
echo "約 2.0 GB のダウンロードが可能な安定した通信環境と、約 3.0 GBのストレージ容量を必要とします。"
echo "下記の質問に y もしくは N で回答してください。"
echo "********************************************************"
read -p "現在の環境は以上の要件を満たしていますか? y: はい, N: いいえ: " IS_SNAPSHOT
if [[ "${IS_SNAPSHOT}" != "y" ]]; then
    echo "環境が整ってから再度実行してください。"
    exit 1
fi


# 移行開始
echo "********************************************************"
echo "CentOS から Oracle Linux へ移行を開始します。"
echo "移行中、デスクトップの壁紙が正常に映らなくなる場合があります。"
echo "********************************************************"

# dnf-automatic.timer を停止し、自動更新を停止する
systemctl stop dnf-automatic.timer
kill -9 $(pgrep dnf-automatic)
systemctl disable dnf-automatic.timer

# centos2ol.sh の存在チェックと削除
cd
if [[ -f centos2ol.sh ]]; then
    rm centos2ol.sh -f;
fi

# centos2ol.sh をダウンロード
wget https://raw.githubusercontent.com/oracle/centos2ol/main/centos2ol.sh

# centos2ol.sh の権限を設定
chmod 700 centos2ol.sh

# centos2ol.sh を実行
# -V オプションで切り替え前と切り替え後のRPM情報の確認 (Verify RPM information before and after the switch)
# -k オプションで Unbreakable Enterprise Kernel(UEK) のインストールを実行せず、無効化する
./centos2ol.sh -V -k

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

# CentOS 由来パッケージの入れ替え・削除
dnf -y swap centos-indexhtml redhat-indexhtml --nobest

# dnf コマンドを実行時の競合を解消
# ディストリビューション固有のモジュールストリームを切り替える
sed -i -e 's|rhel8|ol8|g' /etc/dnf/modules.d/*.module

# 問題のある module をリセット
dnf -y module reset virt

# dnf-rpmfusion リポジトリの追加 (priority=25)
# Oracle Linux への移行処理でリポジトリが削除されているため、再追加する
dnf -y install https://download1.rpmfusion.org/free/el/rpmfusion-free-release-8.noarch.rpm
yes no | cp -ai /etc/yum.repos.d/rpmfusion-free-updates.repo{,.default}
dnf config-manager --disable rpmfusion-free-updates
dnf config-manager --setopt="rpmfusion-free-updates.priority=25" --save rpmfusion-free-updates

# kernel をアップデート
dnf -y update kernel

# 移行完了
rpm -qi oraclelinux-release > /dev/null
RET=$?
echo "********************************************************"
if [[ "${RET}" -eq 0 ]]; then
    echo "Oracle Linux への移行が完了しました。"
    echo "エラーが表示されている場合は RAT までスクリーンショット等を添付して相談してください。"
    echo "reboot コマンドを実行して反映し、RAT からの案内手順に従って操作を続けてください。"
else
    echo "Oracle Linux への移行に失敗しました。"
    echo "表示されているテキストメッセージをすべてコピーして RAT へ相談するか、"
    echo "Linux 上のデータはすべて消えますが、イメージを丸ごと差し替えて移行する方法を検討してください。"
    echo "なお RAT からの案内手順に従い、スナップショットから復元することでこのスクリプトを実行する前の状態に戻ることができます。"
    exit 1
fi
echo "********************************************************"


# Laptop2020-CentOS-To-OracleLinux.sh を削除
rm -f "${0}"
