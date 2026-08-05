# Ensures the current directory ends up being the mushroom-observer
# repo root: no-ops if already inside one, otherwise clones into
# ./mushroom-observer and cd's into it.
#
# Deliberately dependency-free and Bash-3.2-safe: this is the one
# piece of dev-setup logic that has to work before any other script/
# file can be sourced (sourcing requires a local checkout to exist).
# Entry-point scripts source this file directly when run from an
# existing checkout, or via `source <(curl -s ...)` when curl-piped
# on a fresh machine with nothing cloned yet -- see script/dev_setup_macos
# and script/dev_setup_ubuntu for the exact bootstrap snippet.
mo_ensure_repo() {
    if [ -f .ruby-version ] && [ -d app ] && [ -f config/application.rb ]; then
        return 0 # already inside an existing checkout
    fi
    if [ ! -d mushroom-observer/app ]; then
        [ -d mushroom-observer ] && rm -rf mushroom-observer # must be clean or clone fails
        echo "Cloning mushroom-observer..."
        git clone git@github.com:MushroomObserver/mushroom-observer.git ||
            git clone https://github.com/MushroomObserver/mushroom-observer.git
    fi
    cd mushroom-observer || exit 1
}
