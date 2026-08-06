# Installs a gem at the exact version Gemfile.lock expects, when known
# -- falls back to unpinned if the version can't be determined (e.g.
# Gemfile.lock's format ever changes). Installing the locked version
# up front means `bundle install` finds it already satisfied instead
# of resolving and compiling a second, different version -- pinning
# matters most for trilogy, which has a native C extension.
mo_gem_install_locked() {
    gem_name="$1"
    locked_version="$2"

    if [ -n "$locked_version" ]; then
        gem install "$gem_name" -v "$locked_version"
    else
        gem install "$gem_name"
    fi
}

# The shared tail sequence for both platform setup scripts. Before this:
# - the repo has been cloned
# - Bash/Ruby are sorted
# - system packages are installed
#
# Run from inside the mushroom-observer directory, after
# sourcing common.sh (this calls straight into its functions).
#
# Pass the platform ("macos" or "ubuntu"). Three things differ between them:
# - the database.yml template directory
# - jpegresize's gcc flags
# - the root-mysql invocation
mo_finish_app_setup() {
    platform="$1"

    case "$platform" in
        macos)
            database_template_dir="macos"
            gcc_flags="-I$(brew --prefix libjpeg)/include -L$(brew --prefix libjpeg)/lib"
            root_mysql_cmd="mysql -u root -proot"
            ;;
        ubuntu)
            database_template_dir="vagrant"
            gcc_flags=""
            root_mysql_cmd="sudo mysql -u root"
            ;;
        *)
            echo "mo_finish_app_setup: unknown platform '$platform' (expected macos or ubuntu)" >&2
            exit 1
            ;;
    esac

    mo_copy_config_template "db/$database_template_dir/database.yml" config/database.yml
    mo_copy_config_template config/gmaps_api_key.yml-template config/gmaps_api_key.yml
    mo_require_master_key
    mo_create_image_dirs
    mo_build_image_helpers "$gcc_flags"

    echo "Ensure we have the bundler/trilogy versions Gemfile.lock expects"
    bundler_version=$(grep -A1 "^BUNDLED WITH" Gemfile.lock | tail -1 | tr -d ' ')
    trilogy_version=$(grep -E '^    trilogy \(' Gemfile.lock |
        grep -oE '[0-9.]+' | head -1)
    mo_gem_install_locked bundler "$bundler_version"
    mo_gem_install_locked trilogy "$trilogy_version"

    bundle install

    mo_init_or_migrate_db "$root_mysql_cmd"

    bin/rails lang:update

    mo_install_precommit_hook
}
