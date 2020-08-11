#!/usr/bin/env bash
set -Eeo pipefail
trap 'echo && err "Aborted due to error" && exit 1' ERR
trap 'echo && err "Aborted by user" && exit 1' SIGINT
usage() {
    echo
    echo "Usage:"
    echo "  bash ./setup.sh [-h | --help] [-v | --verbose]"
    echo
    echo "Options:"
    echo "  -h, --help        Display this help and exit"
    echo "  -v, --verbose     Print extra information during install"
    echo
}
main() {
    echo && banner
    sanity_check
    parse_opts "$@"
    echo
    info "This script will prepare a fresh server and install Servidor."
    info "If this is not a fresh server, your mileage may vary."
    if is_interactive && ! ask "Continue with install?"; then
        err "Installation aborted." && exit 1
    fi
    start_install
    install_servidor
}
sanity_check() {
    # shellcheck disable=SC2251
    ! getopt -T > /dev/null
    if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
        echo "Enhanced getopt is not available. Aborting."
        exit 1
    fi
    if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
        echo "Your version of Bash is ${BASH_VERSION} but install requires at least v4."
        exit 1
    fi
}
parse_opts() {
    local -r OPTS=hv
    local -r LONG=help,verbose
    local parsed
    # shellcheck disable=SC2251
    ! parsed=$(getopt -o "$OPTS" -l "$LONG" -n "$0" -- "$@")
    if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
        echo "Run 'install.sh --help' for a list of commands."
        exit 2
    fi
    eval set -- "$parsed"
    while true; do
        case "$1" in
            -h|--help)
                usage && exit 0 ;;
            -v|--verbose)
                debug=true; shift ;;
            --)
                shift; break ;;
            *)
                echo "Option '$1' should be valid but couldn't be handled."
                echo "Please submit an issue at https://github.com/dshoreman/servidor/issues"
                exit 3 ;;
        esac
    done
    log "Debug mode enabled"
}
install_servidor() {
    info "Installing Servidor..."
    git clone -q https://github.com/dshoreman/servidor.git /var/servidor
    log "Patching nginx config..."
    nginx_config > /etc/nginx/sites-enabled/servidor.conf
    log " Writing default index page..."
    nginx_default_page > /var/www/html/index.nginx-debian.html
    # NOTE: This should be much more restrictive before final release!
    log " Setting permissions for www-data..."
    echo "www-data ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/www-data
    log " Taking ownership of the Servidor storage dir..."
    chown -R www-data:www-data /var/servidor/storage
    log "Setting owner to www-data on main web root..."
    chown www-data:www-data /var/www
}
ask() {
    echo
    echo -e " \e[1;34m${1}\e[21m [yN]\e[0m"
    read -rp" " response
    [[ "${response,,}" =~ ^(y|yes)$ ]]
}
banner() {
    echo -e " \e[1;36m======================"
    echo "   Servidor Installer"
    echo -e " ======================\e[0m"
}
err() {
    echo -e " \e[1;31m[ERROR]\e[21m ${*}\e[0m"
}
# shellcheck disable=SC2009
is_interactive() {
    ps -o stat= -p $$ | grep -q '+'
}
info() {
    echo -e " \e[1;36m[INFO]\e[0m ${*}\e[0m"
}
log() {
    if [[ ${debug:=} = true ]]; then
        echo -e " \e[1;33m[DEBUG]\e[0m ${*}"
    fi
}
export DEBIAN_FRONTEND=noninteractive
start_install() {
    info "Adding required repositories..."
    add_repos && install_packages
    info "Enabling services..."
    enable_services mariadb nginx php7.4-fpm
}
add_repos() {
    log "Adding ondrej/nginx PPA"
    add-apt-repository -ny ppa:ondrej/nginx
    log "Adding ondrej/php PPA"
    add-apt-repository -ny ppa:ondrej/php
    log "Updating local repositories"
    apt-get update
}
install_packages() {
    info "Installing core packages..."
    install_required sysstat unzip zsh
    info "Installing database and web server..."
    install_required nginx php7.4-fpm
    info "Installing required PHP extensions..."
    install_required composer php7.4-bcmath php7.4-json php7.4-mbstring php7.4-xml php7.4-zip
    info "Installing database..."
    install_required mariadb-server php7.4-mysql
}
install_required() {
    for pkg in "${@}"; do
        log "Installing package ${pkg}..."
        apt-get install -qy --no-install-recommends "${pkg}"
    done
}
enable_services() {
    for svc in "${@}"; do
        systemctl enable "${svc}"
        systemctl restart "${svc}"
    done
}
nginx_config() {
    cat << EOF
server {
    listen 8042 default_server;
    listen [::]:8042 default_server;
    charset utf-8;
    index index.php;
    root /var/servidor/public;
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
    location ~ \.php\$ {
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
    location = /favicon.ico {
        access_log off;
        log_not_found off;
    }
    error_page 404 /index.php;
}
EOF
}
nginx_default_page() {
    cat << EOF
<!DOCTYPE html>
<html>
  <head>
    <title>Site Not Found</title>
    <style type="text/css">
    h1, h2 {
      margin: 0;
    }
    h1 {
      font-size: 200px;
    }
    hr {
      margin: 50px 0;
    }
    .box {
      font-family: sans-serif;
      margin: 0 auto;
      max-width: 1000px;
      min-width: 650px;
      position: absolute;
      transform: translate(-50%, -50%);
      top: 40%;
      left: 50%;
      width: 50%;
      background-position: 100% 35px;
      background-repeat: no-repeat;
      background-image: url(data:image/png;base64,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);
    }
    </style>
  </head>
  <body>
    <div class="box">
      <h1>404</h1>
      <h2>This site doesn't seem to exist yet.</h2>
      <hr>
      <h3>Is this your website?</h3>
      <p>Good news! Your domain is pointed at Servidor.</p>
      <p>Once you've added this domain in Applications, enable it in the Site Editor to go live.</p>
    </div>
  </body>
</html>
EOF
}
main "$@"
