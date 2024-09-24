#!/bin/bash

VERSION=0.0.1
TEMPLATES_GIT_URL=https://github.com/TTTUUUIII/xray-templates.git
ACTION_INIT=1
ACTION_CONFIGURE=2
ACTION_ISSUE_CERT=3
ACTION_SHOW_HELP=4

ACME=$HOME/.acme.sh/acme.sh
CERT_INSTALL_PATH=$HOME/.ssl

my_dir=$(pwd)
ws_path="/v0"
xray_ws_port=8080
xray_tcp_port=80
email=wn123o@outlook.com
domain=snowland.ink
webroot=/var/www/html
ca_server=zerossl
auto_issue_cert=0
action=0

function pr_error() {
    echo -e "\e[31m$1\e[0m"
}

function pr_warn() {
    echo -e "\e[43m$1\e[0m"
}

function parse_arg() {
	local index=$(expr index "$1" "=")
    local key=${1:0:((index - 1))}
	local value=${1:index}
	case $1 in
	--email*)
		email=$value
		;;
	--domain*)
        domain=$value
        ;;
    --webroot*)
        webroot=$value
        ;;
    --auto-issue-cert)
        auto_issue_cert=1
        ;;
    install|init)
        action=$ACTION_INIT
        ;;
    configure)
        action=$ACTION_CONFIGURE
        ;;
    cert)
        action=$ACTION_ISSUE_CERT
        ;;
    help)
        action=$ACTION_SHOW_HELP
        ;;
    *)
        if [ "${1:0:2}" == "--" ];
        then
            pr_warn "unknown option $key, ignored!"
        fi
		;;
	esac

}

function parse_args() {
    for arg in "$@"
    do
        parse_arg $arg
    done

}

function issue_cert() {
    for((i=0;i<$1;++i))
        do
            if [ $i -gt 0 ];
            then
                pr_warn "retry $i"
            fi
            $ACME --issue -d $domain -w $webroot --keylength ec-256 --server $ca_server
            if [ $? -eq 0 ];
            then
                mkdir -p $CERT_INSTALL_PATH
                $ACME --install-cert -d $domain --key-file "$CERT_INSTALL_PATH/$domain.key" --fullchain-file "$CERT_INSTALL_PATH/$domain.pem"
                return $?
            fi
        done

        pr_error "issue cert failed!"
        return 1
}

function install() {

    # install nginx
    if ! nginx -version > /dev/null 2>&1;
    then
        apt udpate
        apt install nginx
    else
        echo "nginx already installed, skipped."
    fi
    
    # install acme.sh
    if ! $ACME -version > /dev/null 2>$1;
    then
        curl https://get.acme.sh | sh -s email=$email
    else
        echo "acme.sh already installed, skipped."
    fi

    # install xray
    if ! xray --version > /dev/null 2>&1;
    then
        bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install -u root
    else
        echo "xray already installed, skipped."
    fi

    # if auto_issue_cert option is specified, we still need issue cert.
    if [ $auto_issue_cert -eq 1 ];
    then
        issue_cert 3
    fi
    
    echo "init completed."
}

function configure() {
    if [ ! -d $HOME/.xray/templates ];
        then
            echo "fetch templates from $TEMPLATES_GIT_URL"
            if ! git clone $TEMPLATES_GIT_URL $HOME/.xray/templates
            then
                exit 1
            fi
        fi

echo """
List of templates:
+-------------------+
| 1. vless+tcp+tls  |
| 2. vless+ws+web   |
+-------------------+
"""

    read -p "Please select a template: " tid
    local uuid=$($HOME/Downloads/Xray-linux-64/xray uuid)
    case $tid in
        1)
            cp -r $HOME/.xray/templates/vless+tcp+tls . \
                && cd vless+tcp+tls \
                && sed -i "s#\$xray_tcp_port#$xray_tcp_port#g" server.json \
                && sed -i "s#\$email#$email#g" server.json \
                && sed -i "s#\$domain#$domain#g" server.json \
                && sed -i "s#\$ssl_full_chain#$CERT_INSTALL_PATH/$domain.pem#g" server.json \
                && sed -i "s#\$ssl_key#$CERT_INSTALL_PATH/$domain.key#g" server.json \
                && sed -i "s#\$domain#$domain#g" nginx.conf \
                && sed -i "s#\$webroot#$webroot#g" nginx.conf \
                && sed -i "s#\$ssl_full_chain#$CERT_INSTALL_PATH/$domain.pem#g" nginx.conf \
                && sed -i "s#\$ssl_key#$CERT_INSTALL_PATH/$domain.key#g" nginx.conf
            ;;
        2)
            cp -r $HOME/.xray/templates/vless+ws+web . \
                && cd vless+ws+web \
                && sed -i "s#\$uuid#$uuid#g" server.json \
                && sed -i "s#\$xray_ws_port#$xray_ws_port#g" server.json \
                && sed -i "s#\$ws_path#$ws_path#g" server.json \
                && sed -i "s#\$domain#$domain#g" nginx.conf \
                && sed -i "s#\$webroot#$webroot#g" nginx.conf \
                && sed -i "s#\$ssl_full_chain#$CERT_INSTALL_PATH/$domain.pem#g" nginx.conf \
                && sed -i "s#\$ssl_key#$CERT_INSTALL_PATH/$domain.key#g" nginx.conf \
                && sed -i "s#\$ws_path#$ws_path#g" nginx.conf \
                && sed -i "s#\$xray_ws_port#$xray_ws_port#g" nginx.conf
            ;;
        *)
            pr_error "$tid not a valid template id!"
            ;;
    esac

    if [ $? -eq 0 ];
    then
        cp nginx.conf /etc/nginx/site-available/$domain \
            && ln -s /etc/nginx/site-enabled/$domain \
            && mkdir -p /usr/local/xray/conf.d \
            && cp server.json /usr/local/etc/xray/conf.d/$(basename `pwd`).json \
            && rm -f /usr/local/etc/xray/conf.d/config.json \
            && ln -s /usr/local/etc/xray/conf.d/$(basename `pwd`).json /usr/local/etc/xray/config.json \
            && systemctl stop xray.service \
            && nginx -s reload \
            && systemctl start xray.service \
            && echo "configuration completed! uuid=$uuid"
    else
        pr_error "generate configuration failed!"
        exit 1
    fi

    cd $my_dir
}

function show_help() {

echo """
version $VERSION
usage: xray_helper.sh [ACTION] [OPTION]...

actions:
    init or install             xray、nginx、acme.sh will be installed.
    configure                   generate xray configure.
    cert                        issue a ssl cert use acme.sh.
    help                        show this help.

options:
    --email                     specify a email. ex: --email=david@outlook.com
    --domain                    specify domain.
    --webroot                   specify web root.
    --auto-issue-cert           vaild when action is install (or init), when this option was specified, an ssl cert will be automatically issue a cert after installed.
"""

}

parse_args $@

case $action in
    $ACTION_INIT)
        install
        ;;
    $ACTION_CONFIGURE)
        configure
        ;;
    $ACTION_ISSUE_CERT)
        issue_cert 3
        ;;
    $ACTION_SHOW_HELP)
        show_help
        ;;
    *)
        if [ "$1" == "" ];
        then
            pr_error "action must be specified!"
        else
            pr_error "unknown \"$1\" action!"
        fi
        show_help
        exit 1
esac
