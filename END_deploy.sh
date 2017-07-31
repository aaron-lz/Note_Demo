#!/bin/bash
echo "#======================================================#"
echo "|                    Deploy  LAMP                      |"
echo "#======================================================#"
echo "|           【1】 ： Install LAMP                      |"
echo "|           【2】 ： Init__set MySQL                   |"
echo "|           【3】 ： Config  MySQL                     |"
echo "|           【4】 ： Config  Apache                    |"
echo "#======================================================#"
echo -e "| \033[31m          【5】 ： Full Deployment     \033[0m              |"
echo -e "| \033[31m          【6】 ： Upgrade Deployment     \033[0m           |"
echo -e "| \033[31m          【7】 ： Restore Site           \033[0m           |"
echo -e "| \033[31m          【8】 ： Separate  Site         \033[0m           |"
echo -e "| \033[31m          【9】 ： Upgrade Separate       \033[0m           |"
echo "#======================================================#"
echo "|                                                      |"
echo -e "| \033[31m          【10】： Crack  MySQL    \033[0m                  |"
echo -e "| \033[31m          【13】： Remove  LAMP    \033[0m                  |"
echo "#======================================================#"
echo "|           Enter  anything  to Quit                   |"
echo "#======================================================#"
read -p "Please input option number :" OP_num
# ---  Declare all variables
D_PATH=/root/tools/html
YUMPATH=/etc/yum.repos.d
C_YUM=/root/tools/lamp56
DB_PATH=/root/tools/ykj.sql
HTTPCFG=/etc/httpd/conf/httpd.conf
IPADDR=$(ifconfig |egrep "192"|egrep -v "192.168.0.*"|awk '{print $2}'|tr -d "addr:")
CONF_PHP=Application/Common/Conf/config.php
#  --- Declare environment variable  --- 
export DB_name
export DB_user
export USER_pwd
export OLD_pwd
export NEW_pwd
export LOGIN_DB
export SITE_doc
# --- config YUM  ---
\mv /${YUMPATH}/* /tmp/
cat>${YUMPATH}/lamp.repo<<EOF
[lmap]
name=lamp
baseurl=file://${C_YUM}
enable=1
gpgcheck=0
EOF

# --- Install LAMP --- 
function INSTALL(){
	rpm -qa|egrep "mysql_community|php56w|httpd" >/dev/null 2>&1
	if [[ $? -ne 0 ]];then
		yum -y install php56w php56w-opcache php56w-bcmath php56w-odbc php56w-soap php56w-mssql php56w-cli php56w-devel php56w-pdo php56w-xmlrpc php56w-xml php56w-gd php56w-mysql php56w-common php56w-mbstring php56w-mcrypt httpd mysql-community-server >/dev/null 2>&1
		for i in mysqld httpd
		do
			service ${i} restart >/dev/null 2>&1
			chkconfig ${i} on
		done
	else
		echo "LAMP is exist ,Please Check off !"
		exit 1
	fi
}
# ---  Init  MySQL ---
function INIT_MySQL(){
read -p "Please input odl Database root Password :" OLD_pwd
read -p "Please input new Database root Password :" NEW_pwd
mysql_secure_installation <<EOF >/dev/null 2>&1
${OLD_pwd}
y
${NEW_pwd}
${NEW_pwd}
y
y
n
y
EOF
export NEW_pwd
}
# --- Config MySQL --- 
function CONF_MySQL(){
read -p "Please input Database that you want create :" DB_name
read -p "Please input User that you want create :" DB_user
read -p "Please input the Password for the User :" USER_pwd
if [[ -z "${NEW_pwd}" ]];then
	read -p "Please input MySQL root login Password :" NEW_pwd
fi
LOGIN_DB="mysql -uroot -p${NEW_pwd}"
${LOGIN_DB} -e "
drop database if exists ${DB_name};
create database ${DB_name};
grant all privileges on ${DB_name}.* to '${DB_user}'@'localhost' identified by '${USER_pwd}';
flush privileges;
use ${DB_name};
source ${DB_PATH};
" >/dev/null 2>&1
export DB_name
export DB_user
export NEW_pwd
export USER_pwd
}
# --- Config Apache  ---   
function CONF_HTTPD(){
	cat ${HTTPCFG}|egrep "\bServerName\b"|"\bNameVirtualHost\b" >/dev/null 2>&1
	if [[ $? -ne 0 ]];then
		sed -i "s/#\(ServerName\) www.example.com/\1 ${IPADDR}/" ${HTTPCFG}
		sed -i "s/#\(NameVirtualHost\) \*/\1 ${IPADDR}/" ${HTTPCFG}
	fi
	read -p "Please input you want to create site(Example: zj.echo.com) :" SITE
	read -p "Please input create site directory  (Example: /var/www/zj) :" SITE_doc
	if [[ ! -d ${SITE_doc} ]];then
		mkdir -p ${SITE_doc}
		\cp -a ${D_PATH}/* ${SITE_doc}
		chown -R apache.apache ${SITE_doc}
	fi
	cat ${HTTPCFG}|egrep "\b${SITE%%.*}\b.echo.com" >/dev/null 2>&1
	if [[ $? -ne 0 ]];then
		sed -i '$a<VirtualHost '${IPADDR}':80>\n\tServerName  '${SITE%%.*}'.echo.com\n\tDocumentRoot '${SITE_doc}'\n</VirtualHost>' ${HTTPCFG}
		service httpd reload >/dev/null 2>&1
	else
		echo "${SITE_doc} is exist !!"
		exit 1
	fi
cat>${SITE_doc}/${CONF_PHP}<<EOF
<?php
return array(
        //'配置项'=>'配置值'
        'URL_MODEL' => 3,
        'DB_DEPLOY_TYPE' => 1, //设置分布式数据库支持
        'DB_TYPE'   => 'mysql', // 数据库类型
        'DB_HOST'   => 'localhost', // 服务器地址
        'DB_NAME'   => '${DB_name}', // 数据库名
        'DB_USER'   => '${DB_user}', // 用户名
        'DB_PWD'    => '${USER_pwd}', // 密码
        'DB_PORT'   => 3306, // 端口
        'DB_PREFIX' => 'ykj_', // 数据库表前缀 
        'DB_CHARSET'=> 'utf8', // 字符集
);
EOF
}
# --- Remove LAMP
function REMOVE_ENSURE(){
	read -p "Are you sure remove LAMP (yes / no):" ENSURE_op
	if [[ ${ENSURE_op} == "yes" ]];then
		REMOVE_LAMP
	fi
}
function REMOVE_LAMP(){
        yum -y remove httpd\* mysql-community\* php56w\* > /dev/null 2>&1
        for j in /var/lib/mysql /var/log/mysqld.log /var/log/httpd /etc/httpd /var/www/*
        do
                rm -rf $j
        done
}
#  --- Crack  MySQL
function STAR_CRACK(){
	mysqld_safe --skip-grant-tables >/dev/null 2>&1 &
	read -p "Please input your modify's root Passwoed :" MD_pwd
	mysql -uroot -e"
update mysql.user set authentication_string=password('${MD_pwd}') where User='root' and Host='localhost';
flush privileges;
grant all privileges on *.* to 'root'@'localhost' identified by '${MD_pwd}';
flush privileges;
"
}
function CRACK_MySQL(){
	service mysqld status >/dev/null 2>&1
	if [[ $? -eq 0 ]];then
		service mysqld stop >/dev/null 2>&1
		STAR_CRACK
	else
		STAR_CRACK
	fi
	mysqladmin -uroot -p${MD_pwd} shutdown >/dev/null 2>&1
	service mysqld restart >/dev/null 2>&1
}
# --- Full Deployment
function FULL_DEPLOY(){
	cat ${HTTPCFG}|egrep "\bServerName\b"|"\bNameVirtualHost\b" >/dev/null 2>&1
	if [[ $? -ne 0 ]];then
		sed -i "s/#\(ServerName\) www.example.com/\1 ${IPADDR}/" ${HTTPCFG}
		sed -i "s/#\(NameVirtualHost\) \*/\1 ${IPADDR}/" ${HTTPCFG}
	fi
	read -p "Please input you want to create site(Example: zj.echo.com) :" SITE
	read -p "Please input create site directory  (Example: /var/www/hy) :" SITE_doc
	SITE_name=${SITE_doc##*/}_apps_$(date +%Y%m%d%H%M%S)
	if [[ ! -d ${SITE_doc} ]];then
		mkdir -p $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}
		\cp -a ${D_PATH}/* $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}
	fi
	cat ${HTTPCFG}|egrep "\b${SITE%%.*}\b.echo.com" >/dev/null 2>&1
	if [[ $? -ne 0 ]];then
		sed -i '$a<VirtualHost '${IPADDR}':80>\n\tServerName  '${SITE%%.*}'.echo.com\n\tDocumentRoot '${SITE_doc}/${SITE_doc##*/}'\n</VirtualHost>' ${HTTPCFG}
		service httpd reload >/dev/null 2>&1
	else
		echo "${SITE_doc} is exist !!"
		exit 1
	fi
	cd $(dirname ${SITE_doc})/${SITE_doc##*/}
	ln -s ${SITE_name} ${SITE_doc##*/}
	chown -R apache.apache $(dirname ${SITE_doc})/${SITE_doc##*/}
	CONF_MySQL
cat>$(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}/${CONF_PHP}<<EOF
<?php
return array(
        //'配置项'=>'配置值'
        'URL_MODEL' => 3,
        'DB_DEPLOY_TYPE' => 1, //设置分布式数据库支持
        'DB_TYPE'   => 'mysql', // 数据库类型
        'DB_HOST'   => 'localhost', // 服务器地址
        'DB_NAME'   => '${DB_name}', // 数据库名
        'DB_USER'   => '${DB_user}', // 用户名
        'DB_PWD'    => '${USER_pwd}', // 密码
        'DB_PORT'   => 3306, // 端口
        'DB_PREFIX' => 'ykj_', // 数据库表前缀 
        'DB_CHARSET'=> 'utf8', // 字符集
);
EOF
}
# --- Upgrade Deployment 
function UPDEPLOY(){
	read -p "Please input you want to Upgrade site(Example:zj) :" SITE
	read -p "Please input upgrade site directory (Example:/var/www/zj) :" SITE_doc
	SITE_name=${SITE_doc##*/}_apps_$(date +%Y%m%d%H%M%S)
	if [[ -d ${SITE_doc} ]];then
		mkdir -p $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}
		\cp -a ${D_PATH}/* $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}
		chown -R apache.apache $(dirname ${SITE_doc})/${SITE_doc##*/}
		cd $(dirname ${SITE_doc})/${SITE_doc##*/}
		rm -rf ${SITE_doc##*/}
		ln -s ${SITE_name} ${SITE_doc##*/}
	fi
	read -p "Please input you specify database :" DB_name
	read -p "Please input User for Database :" DB_user
	read -p "Please input User Password :" USER_pwd

cat>$(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}/${CONF_PHP}<<EOF
<?php
return array(
        //'配置项'=>'配置值'
        'URL_MODEL' => 3,
        'DB_DEPLOY_TYPE' => 1, //设置分布式数据库支持
        'DB_TYPE'   => 'mysql', // 数据库类型
        'DB_HOST'   => 'localhost', // 服务器地址
        'DB_NAME'   => '${DB_name}', // 数据库名
        'DB_USER'   => '${DB_user}', // 用户名
        'DB_PWD'    => '${USER_pwd}', // 密码
        'DB_PORT'   => 3306, // 端口
        'DB_PREFIX' => 'ykj_', // 数据库表前缀 
        'DB_CHARSET'=> 'utf8', // 字符集
);
EOF
}
# --- Restore Site 
function RESTORE(){
read -p "Please input Recovery site (Example:zj):" HF_site
while [[ -z ${HF_site} ]]
do
	read -p "Please Input Site (Example:zj) :" HF_site
done
GET_site=$(find /var/www/* -type d -name "${HF_site}_apps_*" |xargs ls -tdr -1|tail -2|head -1)
result=$(find /var/www/* -type d -name $(basename ${GET_site}))
if [[ -d ${result} ]];then
        cd $(dirname ${result})
        rm -rf ${HF_site}
        ln -s $(basename ${GET_site}) ${HF_site}
fi
}
# --- Star Separate --- 
function SEPARATE_SITE(){
cat ${HTTPCFG}|egrep "\bServerName\b"|"\bNameVirtual\b" >/dev/null 2>&1
if [[ $? -ne 0 ]];then
	sed -i "s/#\(ServerName\) www.example.com/\1 ${IPADDR}/" ${HTTPCFG}
	sed -i "s/#\(NameVirtualHost\) \*/\1${IPADDR}/" ${HTTPCFG}
fi
read -p "Please Input you want to create Site(Example: zj) :" SITE
read -p "Please Input create Site Directory (Example: /var/www/zj) :" SITE_doc
SITE_name=${SITE_doc##*/}_apps_$(date +%Y%m%d%H%F%S)
if [[ ! -d ${SITE_doc} ]];then
	mkdir -p $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}
	mkdir -p $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_doc##*/}_data
	cp -a ${D_PATH}/* $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}
else
	echo "Warning : ${SITE_doc} is exist !!!!!!"
fi
cat ${HTTPCFG}|egrep "\b${SITE%%.*}.echo.com" >/dev/null 2>&1
if [[ $? -ne 0 ]];then
	sed -i '$a<VirtualHost '${IPADDR}':80>\n\tServerName  '${SITE%%.*}'.echo.com\n\tDocumentRoot '${SITE_doc}/${SITE_doc##*/}'\n</VirtualHost>' ${HTTPCFG}
else
	echo "Warning : ${SITE} is exist !!!!!"
fi
cd $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_name}/Public
for i in images Uploads
do
	mv $i $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_doc##*/}_data
	ln -s $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_doc##*/}_data/$i $i
done
cd ..
mv $(dirname ${CONF_PHP}) $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_doc##*/}_data
ln -s $(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_doc##*/}_data/Conf $(dirname ${CONF_PHP})
cd $(dirname ${SITE_doc})/${SITE_doc##*/}
ln -s ${SITE_name} ${SITE_doc##*/}
chown -R apache.apache $(dirname ${SITE_doc})/${SITE_doc##*/}
CONF_MySQL
cat>$(dirname ${SITE_doc})/${SITE_doc##*/}/${SITE_doc##*/}_data/Conf/config.php<<EOF
<?php
return array(
        //'配置项'=>'配置值'
        'URL_MODEL' => 3,
        'DB_DEPLOY_TYPE' => 1, //设置分布式数据库支持
        'DB_TYPE'   => 'mysql', // 数据库类型
        'DB_HOST'   => 'localhost', // 服务器地址
        'DB_NAME'   => '${DB_name}', // 数据库名
        'DB_USER'   => '${DB_user}', // 用户名
        'DB_PWD'    => '${USER_pwd}', // 密码
        'DB_PORT'   => 3306, // 端口
        'DB_PREFIX' => 'ykj_', // 数据库表前缀 
        'DB_CHARSET'=> 'utf8', // 字符集
);
EOF
}
# --- Upgrade Separate ---
function UPGRADE_SEPARATE(){
	read -p "Please Input Upgrade Site (Example:zj) :" SITE
	GET_site=$(find /var/www/* -maxdepth 1 -type d -name "${SITE}")
	cd ${GET_site}
	SITE_name=${SITE}_apps_$(date +%Y%m%d%H%M%S)
	rm -rf ${GET_site##*/}
	mkdir ${SITE_name}
	cp -a ${D_PATH}/* ${SITE_name}
	cd ${SITE_name}/Public
	for i in images Uploads
	do
		rm -rf ${i}
		ln -s ${GET_site}/${SITE}_data/${i} ${i}
	done
	cd ..
	rm -rf $(dirname ${CONF_PHP})
	ln -s ${GET_site}/${SITE}_data/Conf $(dirname ${CONF_PHP})
	cd ..
	ln -s ${SITE_name} ${SITE}
	chown -R apache.apache ${GET_site}
}
# --- Ensure Crack MySQL ---
function ENSURE_CRACK_MySQL(){
	read -p "Are You Sure Reset MySQL ROOT Password(yes / no) :" GET_op
	if [[ ${GET_op} == "yes" ]];then
		CRACK_MySQL
	else
		$0
	fi
}
# --- Restore Env ---
function REST_ENV(){
	rm -rf ${YUMPATH}/*
	\mv /tmp/* ${YUMPATH}/
}
# get user input option number
case ${OP_num} in
	1)
	 echo -e "\e[35;5m####### Installing LAMP ######\e[0m"
	 star=$(date +%s)
	 INSTALL
	 end=$(date +%s)
	 echo "#######  LAMP  complete ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	2)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Initing MySQL ######\e[0m"
	 INIT_MySQL
	 end=$(date +%s)
	 echo "####### MySQL Complete  ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	3)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Config MySQL ######\e[0m"
	 CONF_MySQL
	 end=$(date +%s)
	 echo "####### Config Complete ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	4)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Config HTTPD ######\e[0m"
	 CONF_HTTPD
	 end=$(date +%s)
	 echo "####### Config Complete ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	5)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Star Full Deployment ######\e[0m"
	 FULL_DEPLOY
	 end=$(date +%s)
	 echo "####### Full Deployment Complete   ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	6)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Upgrade Deploy Now ######\e[0m"
	 UPDEPLOY 
	 end=$(date +%s)
	 echo "####### Upgrade Deployment Complete   ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	7)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Restore Site  ######\e[0m"
	 RESTORE
	 end=$(date +%s)
	 echo "####### Restore Completed  ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	8)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### SEPARATE SITE  ######\e[0m"
	 SEPARATE_SITE
	 end=$(date +%s)
	 echo "####### Separate Completed  ######"
	 echo "####### Use $[ end - star ] Second ######"
	 ;;
	9)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### UPGRADE SEPARATE ######\e[0m"
	 UPGRADE_SEPARATE
	 end=$(date +%s)
	 echo "####### Upgrade  Completed  ######"
	 echo "####### Use $[ end - star ] Second ######"
	 ;;
	13)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Removing LAMP ######\e[0m"
	 REMOVE_ENSURE
	 end=$(date +%s)
	 echo "####### Remove Complete ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	10)
	 star=$(date +%s)
	 echo -e "\e[35;5m####### Crack MySQL ######\e[0m"
	 ENSURE_CRACK_MySQL
	 end=$(date +%s)
	 echo "#######  MySQL Crack Complete  ######"
	 echo "####### Use $[ end - star ] Second ######"
	 $0
	 ;;
	*)
	 REST_ENV
	 exit
	 ;;
esac
