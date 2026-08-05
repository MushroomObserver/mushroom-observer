# Shared functions for the per-platform dev onboarding scripts
# (script/dev_setup_macos, script/dev_setup_ubuntu). Source this, then call
# whichever functions apply, in order, from the calling script.
#
# Every function is idempotent -- safe to re-run the whole setup
# script after a partial failure without redoing completed work.
#
# Deliberately NOT included here: cloning the repo. Sourcing this
# file requires the repo to already exist on disk (that's how you got
# this file), so the clone-if-missing step has to stay inline in each
# entry-point script, before it sources anything from script/.

# Creates public/images/*, public/test_images/*, and the log files
# the app writes to. Run from inside the mushroom-observer directory.
mo_create_image_dirs() {
    for dir in images test_images; do
        for subdir in thumb 320 640 960 1280 orig; do
            if [ ! -d "public/$dir/$subdir" ]; then
                mkdir -p "public/$dir/$subdir"
                echo "Created public/$dir/$subdir"
            else
                echo "public/$dir/$subdir exists"
            fi
        done
    done

    mkdir -p log
    for log_file in log/test.log log/production.log; do
        if [ ! -f "$log_file" ]; then
            touch "$log_file"
            echo "Created $log_file"
        else
            echo "$log_file exists"
        fi
    done
}

# Compiles jpegresize and installs exifautotran into /usr/local/bin.
# Pass any extra gcc flags jpegresize.c needs to find libjpeg on this
# platform (e.g. Homebrew's -I/-L on macOS; empty on Ubuntu, where
# apt already puts libjpeg headers on the default search path).
mo_build_image_helpers() {
    extra_gcc_flags="${1:-}"

    if [ ! -f /usr/local/bin/jpegresize ]; then
        # shellcheck disable=SC2086
        sudo gcc script/jpegresize.c $extra_gcc_flags -ljpeg -lm -O2 \
            -o /usr/local/bin/jpegresize
        echo "Created and installed jpegresize executable"
    else
        echo "jpegresize exists"
    fi

    if [ ! -f /usr/local/bin/exifautotran ]; then
        sudo cp script/exifautotran /usr/local/bin/exifautotran
        sudo chmod 755 /usr/local/bin/exifautotran
        echo "Installed exifautotran script"
    else
        echo "exifautotran exists"
    fi
}

# Copies a config template to its destination if the destination
# doesn't already exist. Used for both config/database.yml (platform-
# specific template) and config/gmaps_api_key.yml (same template on
# every platform).
mo_copy_config_template() {
    template_path="$1"
    dest_path="$2"

    if [ ! -f "$dest_path" ]; then
        cp "$template_path" "$dest_path"
        echo "Copied $dest_path"
    else
        echo "$dest_path exists"
    fi
}

# config/master.key can't be generated locally -- it has to match the
# real, checked-in config/credentials.yml.enc. Bails with instructions
# rather than taking the shortcut of regenerating credentials.yml.enc
# with throwaway secrets, which would silently break the real file.
mo_require_master_key() {
    if [ ! -f config/master.key ]; then
        echo ""
        echo "config/master.key is missing. This is NOT something to generate"
        echo "yourself -- ask any MO developer for the real key by email, then"
        echo "put it in config/master.key and re-run this script."
        echo "(Do NOT delete config/credentials.yml.enc or run 'rails credentials:edit'"
        echo "to work around this -- that file is correct as checked in.)"
        exit 1
    fi
}

# Creates and populates mo_development if it doesn't exist yet,
# otherwise just runs pending migrations. db/initialize.sql itself
# creates the `mo`/`mo` mysql user (see its createUser() procedure),
# so the check below doubles as "has initialize.sql already run".
#
# Pass the mysql-as-root invocation this platform uses to run
# db/initialize.sql the first time -- this genuinely differs by
# platform, unlike everything else in this function: macOS sets an
# explicit root password ("mysql -u root -proot"), Ubuntu's apt
# mysql-server uses passwordless sudo/unix-socket auth
# ("sudo mysql -u root").
mo_init_or_migrate_db() {
    root_mysql_cmd="$1"

    if mysql -u mo -pmo mo_development -e '' >/dev/null 2>&1; then
        bin/rails db:migrate
        echo "Ran migrations on the mo_development database"
    else
        $root_mysql_cmd <db/initialize.sql
        bin/rails db:environment:set RAILS_ENV=development
        bin/rails db:schema:load
        bin/rails db:fixtures:load
        echo "Created and populated mo_development database"
    fi
}

# Installs the pre-commit hook that blocks direct commits to main.
# Uses `git rev-parse --git-path hooks` rather than a hardcoded
# .git/hooks -- that path is wrong in worktrees (.git is a file
# there, not a directory) and shared-gitdir setups.
mo_install_precommit_hook() {
    hooks_dir=$(git rev-parse --git-path hooks)
    hook_path="$hooks_dir/pre-commit"

    if [ ! -f "$hook_path" ]; then
        mkdir -p "$hooks_dir"
        cat >"$hook_path" <<'EOF'
#!/bin/sh
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ]
then
  echo "Do not commit directly to the $branch branch"
  exit 1
fi
EOF
        chmod +x "$hook_path"
        echo "Installed pre-commit hook"
    else
        echo "$hook_path exists"
    fi
}
