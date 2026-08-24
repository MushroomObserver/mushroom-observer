# One-time, root-only system prep for a fresh Ubuntu box: creates the
# mo user, /var/web, installs apt packages, chruby, and ruby-install.
# Every step is individually idempotent, so this is safe to call even
# if some or all of it already ran.
#
# Called automatically by script/dev_setup_components/dev_setup_ubuntu
# when it detects it's running as root -- see that file for the
# root -> mo handoff.
mo_ubuntu_root_setup() {
    apt update
    DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y install zsh

    username=mo

    if getent passwd "$username" >/dev/null 2>&1; then
        echo "User '$username' already exists"
    else
        useradd -m -G sudo -s /bin/zsh "$username"
        echo "Successfully created user '$username'"
    fi

    user_home=$(getent passwd "$username" | cut -d: -f6)
    zshrc_path="$user_home/.zshrc"
    if [ ! -f "$zshrc_path" ]; then
        cat >"$zshrc_path" <<EOF
# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
bindkey -e
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/$username/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall
EOF
        chown "$username:$username" "$zshrc_path"
        chmod 644 "$zshrc_path"
        echo "Successfully initialized .zshrc for user '$username'"
    else
        echo "$zshrc_path already exists"
    fi

    ssh_dir="$user_home/.ssh"
    if [ ! -e "$ssh_dir" ]; then
        mkdir "$ssh_dir"
        chmod 700 "$ssh_dir"
        if [ -f ~/.ssh/authorized_keys ]; then
            cat ~/.ssh/authorized_keys >>"$ssh_dir/authorized_keys"
            chmod 600 "$ssh_dir/authorized_keys"
        fi
        chown -R "$username:$username" "$ssh_dir"
        echo "Successfully setup SSH for user '$username'"
    else
        echo "$ssh_dir already exists"
    fi

    if [ ! -e /var/web ]; then
        mkdir /var/web
        echo Created /var/web
    else
        echo /var/web already exists
    fi
    # Was chmod 777 (world-writable). Tightened to owner-only write since
    # only mo ever needs to write here (it clones/runs the app as itself)
    # -- revert to 777 if some other flow turns out to need broader write
    # access. Applied unconditionally, not just on fresh creation, so a
    # re-run also fixes a pre-existing dir left over from before this
    # change.
    chown "$username:$username" /var/web
    chmod 755 /var/web

    DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y upgrade
    DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y install \
        tcsh zsh man vim lynx telnet emacs wget build-essential \
        bison libyaml-dev libxslt-dev mysql-server mysql-client \
        libmysqlclient-dev libcurl4-openssl-dev libssl-dev libapr1-dev \
        libaprutil1-dev libreadline-dev zlib1g-dev imagemagick \
        libmagickcore-dev libmagickwand-dev libjpeg-dev libjpeg-progs \
        libimage-exiftool-perl zbar-tools

    cd /tmp || exit 1
    rm -rf build
    mkdir build

    if [ ! -f /usr/local/share/chruby/chruby.sh ]; then
        echo chruby needs to be installed
        cd build || exit 1
        wget https://github.com/postmodern/chruby/archive/master.tar.gz
        tar -xzvf master.tar.gz
        rm master.tar.gz
        cd chruby-master || exit 1
        make install
        cd ../.. || exit 1
        echo Installed chruby
    else
        echo "chruby install skipped: /usr/local/share/chruby/chruby.sh exists"
    fi

    for chruby_source_line in \
        "source /usr/local/share/chruby/chruby.sh" \
        "source /usr/local/share/chruby/auto.sh"; do
        grep -qxF "$chruby_source_line" ~mo/.zshrc 2>/dev/null ||
            echo "$chruby_source_line" >>~mo/.zshrc
    done

    if command -v ruby-install >/dev/null 2>&1; then
        echo "ruby-install already installed, skipping"
    else
        echo ruby-install needs to be installed
        cd build || exit 1
        wget https://github.com/postmodern/ruby-install/archive/master.tar.gz
        tar -xzvf master.tar.gz
        cd ruby-install-master || exit 1
        make install
        cd ../.. || exit 1
        echo Installed ruby-install
    fi

    rm -rf build

    if [ "$(passwd -S "$username" | awk '{print $2}')" != "P" ]; then
        echo ""
        echo "Set a password for the '$username' user -- needed for sudo to"
        echo "work as '$username' in the next phase:"
        if ! passwd "$username"; then
            echo ""
            echo "ERROR: could not set a password for '$username'. If this ran"
            echo "via 'curl | bash', that prompt reads from the same stdin bash"
            echo "is still consuming as script source and can't be answered --"
            echo "set it yourself and re-run as $username:"
            echo "  passwd $username"
            echo "  su - $username"
            echo "  curl -s https://raw.githubusercontent.com/MushroomObserver/mushroom-observer/HEAD/script/dev_setup | bash"
            exit 1
        fi
    fi
}
