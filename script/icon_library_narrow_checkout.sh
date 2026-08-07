# Narrows an icon-library checkout to just mo-icons.svg -- `--sparse`
# alone at clone time still keeps every other root file (Gemfile,
# README.md, etc). Shared by deploy.sh, ci_rails.yml, and
# sync_mo_icon_library.sh. $1: the checkout directory.
icon_library_narrow_checkout() {
    git -C "$1" sparse-checkout set --no-cone '/mo-icons.svg'
}
