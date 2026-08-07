# Clones (or updates) the private, licensed icon-library repo into
# tmp/icon-library/, then copies its mo-icons.svg into
# vendor/assets/images/icons/ -- part of the regular dev-setup flow
# (called from mo_finish_app_setup) since every dev needs working
# icons. Best-effort: not every dev has icon-library access yet, so a
# failure here is a warning, not a reason to abort the rest of setup
# -- whatever mo-icons.svg is already committed keeps working either
# way. After a successful sync, `git add
# vendor/assets/images/icons/mo-icons.svg` and commit to actually
# update the tracked copy.
#
# Clones to tmp/ (already gitignored wholesale), not straight into
# vendor/assets/images/icons/: that directory tracks mo-icons.svg
# itself, and a `git clone` target ends up containing its own nested
# .git -- git treats a tracked path holding a nested repo as an
# "embedded repository" boundary and refuses to let individual files
# inside it be added to the outer repo normally. Keeping the clone
# separate from the tracked file's location sidesteps that entirely.
#
# Sparse-checkout, not a full clone: that repo's sources/ (the full
# GLYPHICONS 2.0 sprites + fonts the curated sprite gets built from)
# is much larger than what this needs, which is just the top-level
# files. `--sparse` alone (no further `sparse-checkout set` needed)
# defaults to cone mode's top-level-files-only checkout, which
# already excludes sources/ -- confirmed via a real clone that
# sources/ never lands on disk AND its blobs are never fetched
# (--filter=blob:none), not just hidden by the working-tree filter.
#
# Callable standalone via `script/dev_setup_macos --icons-only` or
# `script/dev_setup_ubuntu --icons-only`, without running the rest of
# either setup script -- e.g. to pull a fresh mo-icons.svg and commit
# it after updating icon-library.
mo_sync_icon_library() {
    clone_dir="tmp/icon-library"
    tracked_svg="vendor/assets/images/icons/mo-icons.svg"

    # Scratch clone location under tmp/, gitignored wholesale --
    # auto-removing stale/non-git content here and replacing it with
    # a fresh clone is safe enough to not need a human to intervene
    # first, as long as it's logged, not silent.
    if [ -d "$clone_dir" ] && [ ! -d "$clone_dir/.git" ]; then
        echo "$clone_dir exists but isn't a git checkout -- removing it so a"
        echo "fresh clone can take its place."
        rm -rf "$clone_dir"
    fi

    if [ -d "$clone_dir/.git" ]; then
        origin=$(git -C "$clone_dir" remote get-url origin 2>/dev/null)
        case "$origin" in
            *MushroomObserver/icon-library*)
                if git -C "$clone_dir" pull --quiet; then
                    echo "Updated $clone_dir"
                else
                    echo "WARNING: failed to update $clone_dir (network issue?)"
                    echo "-- leaving the existing checkout as-is."
                fi
                ;;
            *)
                echo "$clone_dir exists but isn't a MushroomObserver/icon-library"
                echo "checkout -- leaving it alone."
                return
                ;;
        esac
    elif git clone --quiet --filter=blob:none --sparse \
        git@github.com:MushroomObserver/icon-library.git \
        "$clone_dir" 2>/dev/null ||
        git clone --quiet --filter=blob:none --sparse \
            https://github.com/MushroomObserver/icon-library.git \
            "$clone_dir" 2>/dev/null; then
        echo "Cloned $clone_dir"
    else
        echo "Could not clone MushroomObserver/icon-library (no access yet?) --"
        echo "skipping. Ask an MO admin for access if you need it; the rest of"
        echo "setup doesn't depend on it."
        return
    fi

    if [ -f "$clone_dir/mo-icons.svg" ]; then
        mkdir -p "$(dirname "$tracked_svg")"
        cp "$clone_dir/mo-icons.svg" "$tracked_svg"
        echo "Copied mo-icons.svg to $tracked_svg -- commit it to update."
    else
        echo "WARNING: $clone_dir/mo-icons.svg not found -- nothing copied."
    fi
}
