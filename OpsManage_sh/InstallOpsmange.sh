#!/bin/bash
#Name InstallOpsManage
#Create by li
#Use environment = centos 7.5
#
#
echo "========================================================================="
echo "=========                   1.定义变量及相关配置及位置             ======"
echo "========================================================================="
#通用
SELINUX_PATH=/etc/selinux/config
HOST_NAME='/etc/sysconfig/network'
echo "注意：本脚本可能因为下载某些软件导致脚本运行失败，可自行下载完成，修改对应位置之后运行！当然也可以axel来实现yum断点续传"
#定义下载文件放置位置，可创建软件存放文件夹并进入
#mkdir -p /data/tools
read -p "请输入文件存放位置:" TOOLS_PATH
if [ ! -d "$TOOLS_PATH" ]; then
        mkdir -p $TOOLS_PATH
fi
#TOOLS_PATH=/root
cd $TOOLS_PATH
#网络相关配置文件及位置
#获取本机IP地址
#IPADDR1=/sbin/ifconfig -a|grep inet|grep -v 127.0.0.1|grep -v inet6|awk '{print $2}'|tr -d "addr:" 
#IPADDR1=ip a show dev ens33|grep -w inet|awk '{print $2}'|awk -F '/' '{print $1}'
ETHCONF=/etc/sysconfig/network-scripts/ifcfg-ens33
HOSTS=/etc/hosts
HOSTNAME=`hostname`
DIR=$TOOLS_PATH/backup/`date +%Y%m%d`
#增加GitHub快速下载
GITHUB_IP1='199.232.5.194 github.global.ssl.fastly.net'
GITHUB_IP2='140.82.113.4 github.com'
GITHUB_IP3='185.199.108.153 assets-cdn.github.com'
NETMASK=255.255.255.0
DNS_PATH='/etc/resolv.conf'
sed -i 's/ONBOOT\=no/ONBOOT\=yes/g' ${ETHCONF}
systemctl restart network
IPADDR1=`ip a show dev ens33|grep -w inet|awk '{print $2}'|sed 's/\/.*//'`
_GATEWAT_=`cat /etc/resolv.conf | awk '{print $2}'|tail -1`
echo "========================================================================="
echo "=========                   2.修改主机名与网络配置及更改源         ======"
echo "========================================================================="
echo "........自动获取的ip是$IPADDR1 ..........."
read -p "Please insert ip address:" _ipaddr_
#创建OpsManage管理员账户与密码
read -p "请输入OpsManage管理员账号:" _user_
read -p "请输入OpsManage管理员密码:" _passwd_
read -p "请输入OpsManage管理员邮箱(可随意填写):" _email_
#创建OpsManage数据库管理员密码(账户默认为root，可自行定义)
read -p "请输入运行OpsManage数据库管理员密码:" _mysql_pwd_
#
#修改主机名(简单粗暴)
#hostnamectl set-hostname Zabbix-Server
#或
function Change_hosts(){
if
   [ ! -d $DIR ];then
   mkdir -p $DIR
fi
  cp $HOSTS $DIR 
  read -p "当前主机名为${HOSTNAME},是否修改(y/n):" yn
if [ "$yn" == "Y" ] || [ "$yn" == "y" ]; then
  read -p "请输入主机名：" hdp
  sed -i "2c HOSTNAME=${hdp}" ${HOST_NAME}
  hostnamectl set-hostname ${hdp}
  echo "$_ipaddr_ $hdp">>$HOSTS
  echo "$GITHUB_IP1">>$HOSTS
  echo "$GITHUB_IP2">>$HOSTS
  echo "$GITHUB_IP3">>$HOSTS
  cat $HOSTS |grep 127.0.0.1 |grep "$hdp"
else
  echo "....主机名未修改 .........." 
#fi
fi
}
Change_hosts
#
function Change_ip(){
#判断备份目录是否存在，中括号前后都有空格，！叹号在shell表示相反的意思# 
if
   [ ! -d $DIR ];then
   mkdir -p $DIR
fi
  echo "准备开始改变IP，在此之前备份原来配置"
  cp $ETHCONF $DIR
  grep "dhcp"  $ETHCONF
#如下$?用来判断上一次操作的状态，为0，表示上一次操作状态正确或者成功#   
if
  [ $? -eq 0 ];then
  sed -i 's/dhcp/static/g' $ETHCONF
#awk -F. 意思是以.号为分隔域，打印前三列#   
#.2 是我的网关的最后一个数字，例如192.168.0.2#
  echo -e "IPADDR=$_ipaddr_\nNETMASK=$NETMASK\nGATEWAY=$_GATEWAT_" >>$ETHCONF
  echo "This IP address Change success !"
else
  echo -n  "这个$ETHCONF已存在 ,请确保更改吗？(y/n)":
  read i
fi
if   
  [ "$i" == "y" -o "$i" == "yes" ];then
#awk -F. 意思是以.号为分隔域
count=(`echo $_ipaddr_|awk -F. '{print $1,$2,$3,$4}'`)
 #定义数组， ${#count[@]}代表获取变量值总个数#
A=${#count[@]}
 #while条件语句判断，个数是否正确，不正确循环提示输入，也可以用[0-9]来判断ip#
while
  [ "$A" -ne "4" ]
do
count=(`echo $_ipaddr_|awk -F. '{print $1,$2,$3,$4}'`)
A=${#count[@]}
done
 #sed -e 可以连续修改多个参数#
  sed -i -e 's/^IPADDR/#IPADDR/g' -e 's/^NETMASK/#NETMASK/g' -e 's/^GATEWAY/#GATEWAY/g' $ETHCONF
 #echo -e \n为连续追加内容，并自动换行#
  echo -e "IPADDR=$_ipaddr_\nNETMASK=$NETMASK\nGATEWAY=$_GATEWAT_" >>$ETHCONF
  echo "This IP address Change success !"
else
  echo "This $ETHCONF static exist,please exit"
#  exit $?
fi
}
Change_ip
systemctl restart network
NEW_IP=`ip a show dev ens33|grep -w inet|awk '{print $2}'|sed 's/\/.*//'`
cat >> $DNS_PATH << EOF
nameserver $_GATEWAT_
EOF
systemctl restart network
yum install -y vim wget psmisc
#更换pip阿里源
mkdir -p ~/.pip/
touch ~/.pip/pip.conf
cat >> ~/.pip/pip.conf << EOF
[global]
index-url = https://mirrors.aliyun.com/pypi/simple/
EOF
#增加Mariadb数据库源(本人是使用的国内源（https://www.centos.bz/2017/12/%E5%AE%89%E8%A3%85mariadb%E9%80%9F%E5%BA%A6%E6%85%A2%E7%9A%84%E8%A7%A3%E5%86%B3%E6%96%B9%E6%B3%95-%E4%BD%BF%E7%94%A8%E5%9B%BD%E5%86%85%E6%BA%90/），可自行修改，地址：https://downloads.mariadb.org/mariadb/repositories/#mirror=acorn)
touch /etc/yum.repos.d/MariaDB.repo
cat >> /etc/yum.repos.d/MariaDB.repo << EOF
# MariaDB 10.3 CentOS repository list - created 2019-10-01 13:19 UTC
# http://downloads.mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
#baseurl = http://yum.mariadb.org/10.3/centos7-amd64
baseurl = https://mirrors.ustc.edu.cn/mariadb/yum/10.3/centos7-amd64
gpgkey=https://mirrors.ustc.edu.cn/mariadb/yum/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF
#更换yum源
mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
#更改epel源
mv /etc/yum.repos.d/epel-testing.repo /etc/yum.repos.d/epel-testing.repo.backup
mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup
wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
wget -O /etc/yum.repos.d/epel-testing.repo http://mirrors.aliyun.com/repo/epel-testing.repo
sed -i -e '/mirrors.cloud.aliyuncs.com/d' -e '/mirrors.aliyuncs.com/d' /etc/yum.repos.d/CentOS-Base.repo
yum clean all
yum makecache
systemctl restart network
yum update -y
#
echo "========================================================================="
echo "=========                   3.关闭selinux和防火墙                   ======"
echo "========================================================================="
#关闭selinux
#临时关闭
setenforce 0
#永久关闭（重启后生效）
sed -i 's/SELINUX\=enforcing/SELINUX\=disabled/g' $SELINUX_PATH
#关闭防火墙
##临时关闭firewall
systemctl stop firewalld.service
#禁止firewall开机启动 
systemctl disable firewalld.service
# 
echo "========================================================================="
echo "=========                   4.安装通用组件                          ======"
echo "========================================================================="
echo "ETHCONF=$ETHCONF"
echo "HOSTS=$HOSTS"
echo "HOSTNAME=$HOSTNAME"
echo "获取本机IP地址=$NEW_IP"
#安装控件
yum install -y net-tools tree zip unzip git
#
echo "========================================================================="
echo "=========                   5.安装相关组件                          ======"
echo "========================================================================="
#
#
yum install zlib zlib-devel readline-devel sqlite-devel bzip2-devel  openssl-devel gdbm-devel libdbi-devel ncurses-libs kernel-devel libxslt-devel libffi-devel python-devel zlib-devel openldap-devel sshpass gcc epel-release  supervisor -y
#如果升级报错，可使用下面方法
#cd $TOOLS_PATH
#wget -c -t 0 https://files.pythonhosted.org/packages/30/db/9e38760b32e3e7f40cce46dd5fb107b8c73840df38f0046d8e6514e675a1/pip-19.2.3-py2.py3-none-any.whl
#pip install pip-19.2.3-py2.py3-none-any.whl
cd $TOOLS_PATH
yum remove -y MariaDB-common*
yum install -y autoconf
yum install -y http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm
wget -c -t 0 https://www.percona.com/downloads/Percona-Server-5.6/Percona-Server-5.6.45-86.1/binary/redhat/7/x86_64/Percona-Server-5.6.45-86.1-r5bc37b1-el7-x86_64-bundle.tar
tar -xvf Percona-Server-5.6.45-86.1-r5bc37b1-el7-x86_64-bundle.tar
rpm -ivh Percona-Server-56-debuginfo-5.6.45-rel86.1.el7.x86_64.rpm
rpm -ivh Percona-Server-shared-56-5.6.45-rel86.1.el7.x86_64.rpm
rpm -ivh Percona-Server-client-56-5.6.45-rel86.1.el7.x86_64.rpm
rpm -ivh Percona-Server-server-56-5.6.45-rel86.1.el7.x86_64.rpm
yum update -y
yum install -y mysql-devel
echo "========================================================================="
echo "=========                   5.安装相Python                         ======"
echo "========================================================================="
cd $TOOLS_PATH
PYTHON_PATH=/usr/local/python3
wget -c -t 0 https://www.python.org/ftp/python/3.6.6/Python-3.6.6.tgz
tar -xzvf Python-3.6.6.tgz
cd Python-3.6.6
./configure --prefix=$PYTHON_PATH
make all && make install && make clean && make distclean
ln -s $PYTHON_PATH/bin/pip3 /usr/bin/pip3
pip3 install --upgrade pip
echo "========================================================================="
echo "=========                   6.安装相关模块                          ======"
echo "========================================================================="
cd /mnt/
#git clone -b v3 https://github.com/welliamcao/OpsManage.git
wget -c -t 0 https://codeload.github.com/welliamcao/OpsManage/zip/v3
unzip v3
mv OpsManage-3 OpsManage
OPSMANAGE_PATH=/mnt/OpsManage
cd $OPSMANAGE_PATH
pip3 install -r requirements.txt
echo "========================================================================="
echo "=========                   7.安装redis                            ======"
echo "========================================================================="
cd $TOOLS_PATH
wget -c -t 0 http://download.redis.io/releases/redis-3.2.8.tar.gz
tar -xzvf redis-3.2.8.tar.gz
cd redis-3.2.8
make && make install
sed -i 's/bind 127\.0\.0\.1/bind 127\.0\.0\.1 $NEW_IP/g' redis.conf
sed -i 's/daemonize no/daemonize yes/g' redis.conf
sed -i 's/loglevel notice/loglevel warning/g' redis.conf
sed -i 's/logfile \"\"/logfile \"\/var\/log\/redis.log\"/g' redis.conf
cd ../
REDIS_PATH=/usr/local/redis
mv redis-3.2.8 $REDIS_PATH
$REDIS_PATH/src/redis-server $REDIS_PATH/redis.conf
echo "========================================================================="
echo "=========                   8.配置mysql                            ======"
echo "========================================================================="
sed -i '/\[mysqld\]/a\character_set_server = utf8' /etc/my.cnf
systemctl restart mysqld
systemctl enable mysqld
mysqladmin -u root password $_mysql_pwd_
echo "flush privileges;" | mysql -uroot -p$_mysql_pwd_
mysqladmin -uroot -p$_mysql_pwd_ password $_mysql_pwd_
echo "flush privileges;" | mysql -uroot -p$_mysql_pwd_
# systemctl stop mysqld
# sed -i '/character_set_server = utf8/a\skip-grant-tables' /etc/my.cnf
# echo "use mysql; \nupdate user set password=PASSWORD('$_mysql_pwd_') where user='root';\nflush privileges;" | mysql -uroot -p
# sed -i 's/skip-grant-tables /#skip-grant-tables/g' /etc/my.cnf
# systemctl restart mysqld
echo "create database opsmanage DEFAULT CHARACTER SET utf8 COLLATE utf8_general_ci;" | mysql -uroot -p$_mysql_pwd_
echo "grant all privileges on opsmanage.* to root@'%' identified by '$_mysql_pwd_';" | mysql -uroot -p$_mysql_pwd_
echo "flush privileges;" | mysql -uroot -p$_mysql_pwd_
systemctl restart mysqld
#sed -i 's/host \= 192\.168\.1\.\*/host \= 127\.0\.0\.1/g' $OPSMANAGE_PATH/conf
sed -i 's/\<host = 192.168.1.*\>/host = 127.0.0.1/g' $OPSMANAGE_PATH/conf/opsmanage.ini
sed -i 's/\<server = 192.168.1.*\>/server = 127.0.0.1/g' $OPSMANAGE_PATH/conf/opsmanage.ini
sed -i 's/\<backup_host = 192.168.1.*\>/backup_host = 127.0.0.1/g' $OPSMANAGE_PATH/conf/opsmanage.ini
sed -i 's/\<password = welliam\>/password = '$_mysql_pwd_'/g' $OPSMANAGE_PATH/conf/opsmanage.ini
cd $OPSMANAGE_PATH
$PYTHON_PATH/bin/python3 manage.py makemigrations wiki
$PYTHON_PATH/bin/python3 manage.py makemigrations orders
$PYTHON_PATH/bin/python3 manage.py makemigrations filemanage
$PYTHON_PATH/bin/python3 manage.py makemigrations navbar
$PYTHON_PATH/bin/python3 manage.py makemigrations databases
$PYTHON_PATH/bin/python3 manage.py makemigrations asset
$PYTHON_PATH/bin/python3 manage.py makemigrations deploy
$PYTHON_PATH/bin/python3 manage.py makemigrations cicd
$PYTHON_PATH/bin/python3 manage.py makemigrations sched
$PYTHON_PATH/bin/python3 manage.py makemigrations apply
$PYTHON_PATH/bin/python3 manage.py migrate
#
/usr/bin/expect <<-EOF
set timeout 30
spawn $PYTHON_PATH/bin/python3 manage.py createsuperuser
expect {
"Username*" { send "$_user_\n",exp_continue }
"Email*" { send "$_email_\n",exp_continue }
"Password*" { send "$_passwd_\n",exp_continue }
"Bypass password*" { send "y\n" }
}
expect eof;
EOF
# 如果出现错误ImportError: cannot import name 'LDAPError'
# pip3 uninstall python-ldap
# pip3 install --upgrade python-ldap
echo "========================================================================="
echo "=========                   9.安装Nginx                            ======"
echo "========================================================================="
yum install -y pcre pcre-devel gcc-c++ openssl
cd $TOOLS_PATH
wget -c -t 0 http://nginx.org/download/nginx-1.16.1.tar.gz
tar -zxvf nginx-1.16.1*
cd nginx-1.16*
./configure
make && make install
_WHEREIS_NGINX_=`whereis nginx`
NGINX_PATH=`echo $_WHEREIS_NGINX_ |cut -d' ' -f2`
$NGINX_PATH/sbin/nginx
cp $NGINX_PATH/sbin/nginx /etc/init.d/
chmod +x /etc/init.d/nginx
#设置开机启动nginx
cat >> /etc/rc.local << EOF
$NGINX_PATH/sbin/nginx
EOF
chmod 755 /etc/rc.local
$NGINX_PATH/sbin/nginx
echo "========================================================================="
echo "=========                   10.启动部署平台                         ======"
echo "========================================================================="
SUPER_PATH='/etc/supervisord.conf'
echo_supervisord_conf > $SUPER_PATH
export PYTHONOPTIMIZE=1
cat >> $SUPER_PATH << EOF
[program:celery-worker-default]
command=$PYTHON_PATH/bin/celery -A OpsManage worker --loglevel=info -E -Q default -n worker-default@%%h
directory=$OPSMANAGE_PATH
stdout_logfile=/var/log/celery-worker-default.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
numprocs=1

[program:celery-worker-ansible]
command=$PYTHON_PATH/bin/celery -A OpsManage worker --loglevel=info -E -Q ansible -n worker-ansible@%%h
directory=$OPSMANAGE_PATH
stdout_logfile=/var/log/celery-worker-ansible.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
numprocs=1

[program:celery-beat]
command=$PYTHON_PATH/bin/celery -A OpsManage  beat --loglevel=info --scheduler django_celery_beat.schedulers:DatabaseScheduler
directory=$OPSMANAGE_PATH
stdout_logfile=/var/log/celery-beat.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
numprocs=1

[program:opsmanage-web]
command=$PYTHON_PATH/bin/python3 manage.py runserver 0.0.0.0:8000 --http_timeout 1200
directory=$OPSMANAGE_PATH
stdout_logfile=/var/log/opsmanage-web.log   
stderr_logfile=/var/log/opsmanage-web-error.log
autostart=true
autorestart=true
redirect_stderr=true
stopsignal=QUIT
EOF
#
#启动celery
supervisord -c $SUPER_PATH
#配置nginx
mkdir -p /var/log/nginx
touch /var/log/nginx/opsmanage_access.log
sed -i 's/\<listen       80;\>/listen       80;/g' $NGINX_PATH/conf/nginx.conf
sed -i '/server_name  localhost;/a\        access_log \/var\/log\/nginx\/opsmanage_access.log;\n        error_log \/var\/log\/nginx\/opsmanage_error.log;' $NGINX_PATH/conf/nginx.conf
sed -i '/index  index.html index.htm;/a\            proxy_next_upstream off;\n            proxy_set_header    X-Real-IP           $remote_addr;\n            proxy_set_header    X-Forwarded-For     $proxy_add_x_forwarded_for;\n            proxy_set_header    Host                $host;\n            proxy_http_version 1.1;\n            proxy_set_header Upgrade $http_upgrade;\n            proxy_set_header Connection "upgrade";\n            proxy_pass http:\/\/\'$NEW_IP':8000$request_uri;' $NGINX_PATH/conf/nginx.conf
sed -i '/deny  all;/a\        location \/static {\n         expires 30d;\n         autoindex on;\n         add_header Cache-Control private;\n         alias \/mnt\/OpsManage\/static\/;\n      }\n' $NGINX_PATH/conf/nginx.conf
$NGINX_PATH/sbin/nginx -s reload
#
#重启
shutdown -t 30 -r
#reboot
