# Clones (or updates) the private, licensed icon-library repo into
# tmp/icon-library/, then copies its mo-icons.svg into
# vendor/assets/images/icons/ -- part of the regular dev-setup flow
# (called from mo_finish_app_setup) since every dev needs working
# icons once Components::Icon actually renders them. Best-effort: not
# every dev has icon-library access yet, so a failure here is a
# warning, not a reason to abort the rest of setup -- nothing in the
# app requires the sprite yet either way.
#
# mo-icons.svg is never committed here -- vendor/assets/images/icons/
# is gitignored wholesale, since this repo is public/MIT-licensed and
# stays free of any copyrighted material, even a curated derivative.
# CI and production each fetch their own copy independently (see
# .github/workflows/ci_rails.yml and deploy.sh --icons-only) rather
# than relying on a committed file.
#
# Clones to tmp/ (already gitignored wholesale), not straight into
# vendor/assets/images/icons/, even though nothing there is tracked
# today: a `git clone` target ends up containing its own nested .git,
# which git treats as an "embedded repository" boundary and refuses
# to let individual files inside it be added to the outer repo
# normally. Keeping the clone separate from where the file actually
# lands means that's never a problem, including if this directory
# ever does start tracking something.
#
# Sparse-checkout, not a full clone -- see
# script/icon_library_narrow_checkout.sh for why it's narrowed further
# to just mo-icons.svg.
#
# Callable standalone via `script/dev_setup --icons-only`, without
# running the rest of setup -- e.g. to pick up a fresh mo-icons.svg
# locally after icon-library updates.
mo_sync_icon_library() {
    clone_dir="tmp/icon-library"
    dest_svg="vendor/assets/images/icons/mo-icons.svg"

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

    source script/icon_library_narrow_checkout.sh
    if ! icon_library_narrow_checkout "$clone_dir"; then
        echo "WARNING: narrowing $clone_dir to mo-icons.svg failed -- extra"
        echo "root files (Gemfile, README.md, etc.) may still be present."
    fi

    if [ -f "$clone_dir/mo-icons.svg" ]; then
        mkdir -p "$(dirname "$dest_svg")"
        cp "$clone_dir/mo-icons.svg" "$dest_svg"
        echo "Copied mo-icons.svg to $dest_svg."
    else
        echo "WARNING: $clone_dir/mo-icons.svg not found -- nothing copied."
    fi
}
