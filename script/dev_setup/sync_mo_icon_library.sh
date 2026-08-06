# Clones (or updates) the private, licensed icon-library repo into
# vendor/assets/images/icons/. Best-effort: not every dev has access
# yet, and nothing in the app references these assets yet, so a
# failure here is a warning, not a reason to abort the rest of setup.
#
# Sparse-checkout, not a full clone: that repo's sources/ (the full
# GLYPHICONS 2.0 sprites + fonts the curated sprite gets built from)
# is much larger than what MO actually needs at runtime, which is
# just mo-icons.svg. `--sparse` alone (no further `sparse-checkout
# set` needed) defaults to cone mode's top-level-files-only checkout,
# which already excludes sources/ -- confirmed via a real clone that
# sources/ never lands on disk AND its blobs are never fetched
# (--filter=blob:none), not just hidden by the working-tree filter.
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
    elif git clone --quiet --filter=blob:none --sparse \
        git@github.com:MushroomObserver/icon-library.git \
        "$icons_dir" 2>/dev/null ||
        git clone --quiet --filter=blob:none --sparse \
            https://github.com/MushroomObserver/icon-library.git \
            "$icons_dir" 2>/dev/null; then
        echo "Cloned $icons_dir"
    else
        echo "Could not clone MushroomObserver/icon-library (no access yet?) --"
        echo "skipping. Ask an MO admin for access if you need it; the rest of"
        echo "setup doesn't depend on it."
    fi
}
