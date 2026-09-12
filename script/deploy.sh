#!/usr/bin/env bash

if [ "$PWD" != "/var/web/mo" ]; then
    echo Please run this from /var/web/mo.
    exit 1
fi

if [ "$USER" != "mo" ]; then
    echo Please run this as the mo user.
    exit 1
fi

if [ "$RAILS_ENV" != "production" ]; then
    echo Please set RAILS_ENV to production.
    exit 1
fi

# Icon-library refresh, shared by --icons-only (asset-only, no code
# deploy) and --icons (bundled into a normal code deploy below).
# Nothing else valid lives in $icons_dir, so a stale/broken checkout
# is clobbered and re-cloned rather than pulled or preserved -- pull
# can't recover from a non-git or wrong-remote directory, and this
# way there's only one code path instead of pull-if-clean-else-abort.
refresh_icon_library() {
    icons_dir="vendor/assets/images/icons"

    echo "Refreshing $icons_dir..."
    rm -rf "$icons_dir"
    git clone --filter=blob:none --sparse \
        git@github.com:MushroomObserver/icon-library.git "$icons_dir" ||
        git clone --filter=blob:none --sparse \
            https://github.com/MushroomObserver/icon-library.git "$icons_dir"
    if [ $? -ne 0 ]; then
        echo Cloning the icon library failed.
        return 1
    fi

    source script/icon_library_narrow_checkout.sh
    icon_library_narrow_checkout "$icons_dir"
    if [ $? -ne 0 ]; then
        echo Narrowing the icon-library checkout to mo-icons.svg failed.
        return 1
    fi

    # A successful clone doesn't guarantee mo-icons.svg itself is
    # there -- verify explicitly rather than trusting the command's
    # exit status alone. Production without icons is a real
    # regression (illegible site), not a tolerable degraded state
    # (contrast with the best-effort skip elsewhere for CI/dev), so
    # this is a hard failure.
    if [ ! -f "$icons_dir/mo-icons.svg" ]; then
        echo "$icons_dir/mo-icons.svg is missing after the clone --"
        echo "check icon-library's main branch. Aborting rather than"
        echo "precompiling and reloading without a working icon sprite."
        return 1
    fi
}

# Glyph keys Components::Icon::GLYPHS references that the current
# sprite checkout lacks (one per line; empty when in sync). A missing
# or unreadable sprite counts every glyph as lacking, so a wiped
# checkout heals itself via the auto-refresh below.
missing_icon_glyphs() {
    ruby -e '
      # An unreadable icon.rb or an unmatched GLYPHS extraction exits
      # non-zero: the check must fail loudly rather than silently
      # reporting "in sync" when it cannot actually diff.
      src = begin
        File.read("app/components/icon.rb")
      rescue StandardError => e
        abort("cannot read app/components/icon.rb: #{e.message}")
      end
      list = src[/GLYPHS = Set\[(.*?)\]/m, 1] ||
             abort("cannot find GLYPHS in app/components/icon.rb -- " \
                   "update the extraction in script/deploy.sh")
      code = list.scan(/:(\w+)/).flatten
      sprite = begin
        File.read("vendor/assets/images/icons/mo-icons.svg").
          scan(/symbol id="(\w+)"/).flatten
      rescue StandardError
        [] # missing sprite = every glyph lacking; the refresh heals it
      end
      puts(code - sprite)
    '
}

# The manifest entry for the sprite -- the fingerprinted name a
# correctly reloaded app emits in its pages.
expected_sprite_asset() {
    ruby -rjson -e '
      manifest = Dir.glob("public/assets/.sprockets-manifest-*.json").first
      abort("no sprockets manifest under public/assets") unless manifest
      puts(JSON.parse(File.read(manifest))["assets"]["icons/mo-icons.svg"])
    '
}

# Poll the running app (through local nginx; -k because the cert is
# for the public name) until its pages reference the expected sprite
# asset. A puma "reload" can keep the old asset manifest in memory
# while every disk artifact is correct, so the reload's exit
# status alone proves nothing.
served_sprite_matches() {
    expected="$1"
    for _try in 1 2 3 4 5 6 7 8 9 10; do
        served=$(curl -ksS -H "Host: mushroomobserver.org" \
                      https://127.0.0.1/ 2>/dev/null |
                     grep -o "mo-icons-[a-f0-9]*\.svg" | head -1)
        if [ "icons/$served" = "$expected" ]; then
            return 0
        fi
        sleep 3
    done
    echo "App still serves ${served:-no sprite reference}, expected $expected."
    return 1
}

# A standard deploy refreshes the icon library AUTOMATICALLY when the
# pulled code's Icon::GLYPHS references symbols the sprite checkout
# lacks (see missing_icon_glyphs / the auto-detect before the
# icons_flag check further down). The flags cover what
# auto-detection can't:
#
# --icons forces the refresh during a normal code deploy -- for
# artwork-only icon-library changes whose symbol ids didn't change,
# which the glyph diff can't see.
#
# --icons-only is the same forced refresh WITHOUT a code deploy. It
# exits here rather than falling through to the code-deploy flow
# below, since none of that (git branch check, maintenance page,
# puma/solidqueue stop, db:migrate, lang:update) applies to a
# licensed-asset-only refresh.
icons_flag=0
case "$1" in
    --icons-only)
        refresh_icon_library || exit 1

        # Assets are precompiled (config.assets.compile = false in
        # production) and fingerprinted, so new icon files aren't live
        # until recompiled. `service puma reload` sends SIGUSR2 (see
        # config/etc/puma.service's ExecReload) -- Puma's hot restart,
        # which keeps the listening socket, so this needs neither the
        # maintenance page nor a full stop/start. Whether the re-exec
        # picks up the new manifest is verified below, not assumed.
        echo Precompiling assets... && rake assets:precompile
        if [ $? -ne 0 ]; then
            echo assets:precompile failed.
            exit 1
        fi

        expected=$(expected_sprite_asset)
        if [ $? -ne 0 ] || [ -z "$expected" ]; then
            echo "Cannot read the sprite's manifest entry; not reloading."
            exit 1
        fi

        echo Reloading puma... && sudo service puma reload
        if [ $? -ne 0 ]; then
            echo Puma reload failed.
            exit 1
        fi

        # Verify the reload actually took: a hot restart has
        # left the old asset manifest live before, while reporting
        # success. Escalate to a full restart, then fail loudly.
        echo "Verifying the app serves $expected..."
        if ! served_sprite_matches "$expected"; then
            echo "Reload left the old asset manifest live (#5365);"
            echo "escalating to a full puma restart..."
            sudo service puma restart
            if [ $? -ne 0 ]; then
                echo Puma restart failed.
                exit 1
            fi
            if ! served_sprite_matches "$expected"; then
                echo "Restart did not pick up the new manifest either --"
                echo "investigate before trusting this refresh."
                exit 1
            fi
        fi

        echo SUCCESS\!
        exit 0
        ;;
    --icons)
        icons_flag=1
        ;;
esac

if [ "$(git branch | grep '^\*')" != "* main" ]; then
    echo Please switch to main branch.
    exit 1
fi

echo Fetching latest from origin... && git fetch --tags origin
if [ $? -ne 0 ]; then
    echo git fetch failed.
    exit 1
fi

EXPECTED_RUBY=$(git show origin/main:.ruby-version | tr -d '[:space:]')
CURRENT_RUBY=$(ruby -e 'puts RUBY_VERSION')
if [ "$EXPECTED_RUBY" != "$CURRENT_RUBY" ]; then
    echo "Ruby version mismatch!"
    echo "  Running:  $CURRENT_RUBY"
    echo "  Expected: $EXPECTED_RUBY (from origin/main)"
    echo "Please install and activate Ruby $EXPECTED_RUBY before deploying."
    echo "See README_RUBY_34_UPGRADE.md for instructions."
    exit 1
fi

# Pre-release changelog check (issue #5155). The pre-release PR wrote
# the upcoming deploy's tag name into CHANGELOG.md's top heading; a
# top heading whose tag already exists in git means no pre-release ran
# for this deploy. Checked against origin/main (the code that will be
# pulled below), before anything is paused or stopped.
update_article=0
pending_tag=`git show origin/main:CHANGELOG.md 2>/dev/null | \
    grep -m1 -oE '^## [0-9-]+ \(deploy-[0-9-]+\)' | \
    sed -E 's/.*\((deploy-[0-9-]+)\).*/\1/'`
if [ -n "$pending_tag" ] && \
   ! git rev-parse -q --verify "refs/tags/$pending_tag" >/dev/null; then
    tag="$pending_tag"
    update_article=1
    echo "Pre-release found: tagging this deploy $tag and updating the"
    echo "MO Article from article_pending.textile."
else
    echo ""
    echo "WARNING: no pre-release changelog found for this deploy, so"
    echo "CHANGELOG.md has no section for it and the MO Article will not"
    echo "be updated."
    echo ""
    echo "The pre-release process (issue #5155):"
    echo "  1. On a dev machine: ruby script/prerelease.rb --apply"
    echo "     (builds the changelog-pending PR with the next CHANGELOG.md"
    echo "      section and article_pending.textile's MO Article rows)"
    echo "  2. Review and merge that PR as the last PR before deploying."
    echo "  3. Run script/deploy.sh -- it tags the deploy with the"
    echo "     pre-release's tag name and publishes the Article rows."
    echo ""
    echo "Forcing deploys main as-is (useful for an urgent fix); the"
    echo "skipped PRs roll into the next pre-release/deploy cycle."
    printf "Force the deploy without a changelog? [y/N] "
    read -r answer
    case "$answer" in
        y|Y|yes|YES)
            echo "Forcing deploy without changelog or MO Article update."
            ;;
        *)
            echo "Deploy aborted. Run the pre-release, then deploy again."
            exit 1
            ;;
    esac
    tag=`date "+deploy-%Y-%m-%d-%H-%M"`
fi

# Pause all queues so no NEW jobs start, then wait (up to the drain timeout)
# for in-flight jobs to finish. This runs BEFORE anything is stopped, so a
# timeout aborts the deploy with the site still up and the queues left paused
# (resume manually once the stuck job is dealt with).
# See script/pause_and_drain_jobs.rb.
echo Pausing queues and draining in-flight jobs...
bundle exec rails runner script/pause_and_drain_jobs.rb "${DRAIN_TIMEOUT:-300}"
if [ $? -ne 0 ]; then
    echo ""
    echo "Deploy aborted: in-flight jobs did not finish within the timeout."
    echo "The site is still up and queues remain paused (no new jobs start)."
    echo "Deal with the stuck job(s), then resume with:"
    echo "  bundle exec rails runner script/resume_jobs.rb"
    exit 1
fi

# Queues are drained and paused; the pause persists across the restart, so no
# job runs until we resume at the very end.
echo Stopping solidqueue to prevent new jobs during deploy...
sudo service solidqueue stop
if [ $? -ne 0 ]; then
    echo Failed to stop solidqueue.
    echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
    exit 1
fi

echo Going for it\!

# Put up the maintenance page BEFORE stopping puma so users hit a
# friendly 503 (and DigitalOcean's /test check stays green) rather than
# a broken connection during the restart window (#4312). The trap below
# guarantees the sentinel is removed on ANY exit path — normal success,
# explicit `exit 1` in a failure branch, or signal (Ctrl-C / TERM) —
# so a half-failed or interrupted deploy can't strand the site behind
# the maintenance page.
echo Putting up maintenance page...
if ! cp public/maintenance.html.tmpl public/maintenance.html; then
    echo Failed to copy maintenance template. Aborting before touching puma.
    exit 1
fi
trap 'rm -f public/maintenance.html' EXIT INT TERM

echo Stopping puma to update code... && sudo service puma stop

STASH_RESULT=`git stash`
if [ $? -ne 0 ]; then
    echo git stash failed.
    echo Restarting puma... && sudo service puma start
    echo Restarting solidqueue... && sudo service solidqueue start
    echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
    exit 1
fi

echo $STASH_RESULT | grep 'No local changes to save'
STASH_STATUS=$?

if [ $STASH_STATUS -ne 0 ]; then
    echo Stashed some changes...
fi

echo Getting latest code from github... && git pull
if [ $? -ne 0 ]; then
    echo git pull failed.
    echo Restarting puma... && sudo service puma start
    echo Restarting solidqueue... && sudo service solidqueue start
    echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
    exit 1
fi

if [ "$STASH_RESULT" != 'No local changes to save' ]; then
    echo Reapply local changes... && git stash pop
    if [ $? -ne 0 ]; then
	echo Applying the stashed changes failed.
        echo Restarting puma... && sudo service puma start
	echo Restarting solidqueue... && sudo service solidqueue start
	echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
	exit 1
    fi
fi

# Auto-detect icon-library skew: when the just-pulled code's
# Icon::GLYPHS references symbols the sprite checkout lacks, the
# refresh happens as part of this deploy -- shipping code whose icons
# render blank is not an acceptable default. --icons still forces a
# refresh for changes auto-detection can't see (reworked artwork
# whose symbol ids didn't change).
missing_glyphs=$(missing_icon_glyphs)
if [ $? -ne 0 ]; then
    echo "Icon glyph check failed -- cannot verify the sprite matches"
    echo "the code (see the error above)."
    echo "Deploy aborted. Restarting puma and solidqueue with existing code..."
    sudo service puma start
    sudo service solidqueue start
    echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
    exit 1
fi
if [ -n "$missing_glyphs" ]; then
    echo "Icon sprite lacks glyph(s) the code references:" $missing_glyphs
    echo "Refreshing the icon library as part of this deploy."
    icons_flag=1
fi

if [ "$icons_flag" = "1" ]; then
    refresh_icon_library
    if [ $? -ne 0 ]; then
        echo ""
        echo "Deploy failed. Restarting puma and solidqueue with existing code..."
        sudo service puma start
        sudo service solidqueue start
        echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
        exit 1
    fi
    still_missing=$(missing_icon_glyphs)
    if [ $? -ne 0 ]; then
        echo "Icon glyph re-check failed after the refresh (see the error"
        echo "above)."
        echo "Deploy aborted. Restarting puma and solidqueue with existing code..."
        sudo service puma start
        sudo service solidqueue start
        echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
        exit 1
    fi
    if [ -n "$still_missing" ]; then
        echo ""
        echo "Icon library refreshed, but the sprite still lacks:" $still_missing
        echo "icon-library main is behind the app code (CI should have"
        echo "caught this -- see test/classes/icon_glyph_sync_test.rb)."
        echo "Deploy aborted. Restarting puma and solidqueue with existing code..."
        sudo service puma start
        sudo service solidqueue start
        echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
        exit 1
    fi
fi

# Restart puma BEFORE removing the maintenance page so users don't
# briefly see "broken connection" between sentinel removal and puma
# accepting connections. The trap at the top of the script takes the
# sentinel down on EXIT (success or failure), but we want it down
# immediately on success — so do it explicitly right after puma is
# back, then let the trap no-op on exit.
echo Installing bundle... && bundle install && \
echo Checking for migrations... && rake db:migrate && \
echo Updating translations... && script/lang_update_if_needed.sh && \
echo Precompiling assets... && rake assets:precompile && \
echo Starting puma... && sudo service puma start && \
echo Starting solidqueue... && sudo service solidqueue start && \
echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb && \
echo Taking down maintenance page... && rm -f public/maintenance.html

if [ $? -ne 0 ]; then
    echo ""
    echo "Deploy failed. Restarting puma and solidqueue with existing code..."
    sudo service puma start
    sudo service solidqueue start
    echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
    exit 1
fi

# Best-effort (#5155): a failure here warns and the deploy still
# succeeds -- the Article is cosmetic; the site is already up.
if [ "$update_article" = "1" ]; then
    echo Updating the MO Article from article_pending.textile...
    bundle exec rails runner script/update_article_changelog.rb --apply
    if [ $? -ne 0 ]; then
        echo "WARNING: MO Article update failed; the deploy continues."
        echo "Retry by hand:"
        echo "  bundle exec rails runner script/update_article_changelog.rb --apply"
    fi
fi

echo Tagging repo with $tag... && git tag $tag && \
echo Pushing new tag... && git push --tags && \
echo SUCCESS\!

if [ $? -ne 0 ]; then
    echo ""
    echo "Site is up, but tagging/pushing $tag failed. Fix and re-run:"
    echo "  git tag $tag && git push --tags"
    exit 1
fi
