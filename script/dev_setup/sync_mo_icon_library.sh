# Clones (or updates) the private, licensed icon-library repo into
# vendor/assets/images/icons/. Best-effort: not every dev has access
# yet, and nothing in the app references these assets yet, so a
# failure here is a warning, not a reason to abort the rest of setup.
#
# Callable standalone via `script/dev_setup_macos --icons-only` or
# `script/dev_setup_ubuntu --icons-only`, without running the rest of
# either setup script.
mo_sync_icon_library() {
    icons_dir="vendor/assets/images/icons"

    if [ -d "$icons_dir/.git" ]; then
        origin=$(git -C "$icons_dir" remote get-url origin 2>/dev/null)
        case "$origin" in
            *MushroomObserver/icon-library*)
                if git -C "$icons_dir" pull --quiet; then
                    echo "Updated $icons_dir"
                else
                    echo "WARNING: failed to update $icons_dir (network issue?)"
                    echo "-- leaving the existing checkout as-is."
                fi
                ;;
            *)
                echo "$icons_dir exists but isn't a MushroomObserver/icon-library"
                echo "checkout -- leaving it alone."
                ;;
        esac
    elif [ -d "$icons_dir" ]; then
        echo "$icons_dir exists but isn't a git checkout -- leaving it alone."
    elif git clone --quiet git@github.com:MushroomObserver/icon-library.git \
        "$icons_dir" 2>/dev/null ||
        git clone --quiet https://github.com/MushroomObserver/icon-library.git \
            "$icons_dir" 2>/dev/null; then
        echo "Cloned $icons_dir"
    else
        echo "Could not clone MushroomObserver/icon-library (no access yet?) --"
        echo "skipping. Ask an MO admin for access if you need it; the rest of"
        echo "setup doesn't depend on it."
    fi
}
