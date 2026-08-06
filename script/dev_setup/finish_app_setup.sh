# The shared tail sequence for both platform setup scripts, once the
# repo is cloned, Bash/Ruby are sorted, and system packages are
# installed. Run from inside the mushroom-observer directory, after
# sourcing common.sh (this calls straight into its functions).
#
# Pass the three things that genuinely differ by platform:
#   database_template  -- db/macos/database.yml or db/vagrant/database.yml
#   gcc_flags           -- extra -I/-L flags jpegresize.c needs to find
#                           libjpeg (Homebrew's paths on macOS; empty on
#                           Ubuntu, where apt puts headers on the default
#                           search path)
#   root_mysql_cmd       -- "mysql -u root -proot" (macOS, explicit root
#                           password) or "sudo mysql -u root" (Ubuntu,
#                           passwordless sudo/unix-socket auth)
mo_finish_app_setup() {
    database_template="$1"
    gcc_flags="$2"
    root_mysql_cmd="$3"

    mo_copy_config_template "$database_template" config/database.yml
    mo_copy_config_template config/gmaps_api_key.yml-template config/gmaps_api_key.yml
    mo_require_master_key
    mo_create_image_dirs
    mo_build_image_helpers "$gcc_flags"

    echo "Ensure we have the latest bundler"
    gem install bundler
    gem install trilogy

    bundle install

    mo_init_or_migrate_db "$root_mysql_cmd"

    bin/rails lang:update

    mo_install_precommit_hook
}
