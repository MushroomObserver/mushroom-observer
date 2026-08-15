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

# --icons-only is a manual, opt-in icon-library refresh -- deliberately
# NOT part of a standard deploy (the icon-library repo has its own
# release cadence, unrelated to app code). Exits here rather than
# falling through to the code-deploy flow below, since none of that
# (git branch check, maintenance page, puma/solidqueue stop,
# db:migrate, lang:update) applies to a licensed-asset-only refresh.
#
# --icons bundles the same refresh into a normal code deploy (see the
# icons_flag check further down, right before the single
# assets:precompile that deploy already does) -- one precompile
# instead of two separate ones from running --icons-only and a plain
# deploy back to back.
icons_flag=0
case "$1" in
    --icons-only)
        refresh_icon_library || exit 1

        # Assets are precompiled (config.assets.compile = false in
        # production) and fingerprinted, so new icon files aren't live
        # until recompiled. `service puma reload` sends SIGUSR2 (see
        # config/etc/puma.service's ExecReload) -- Puma's hot restart,
        # which re-execs and picks up the new manifest while keeping
        # the listening socket, so this needs neither the maintenance
        # page nor a full stop/start.
        echo Precompiling assets... && rake assets:precompile
        if [ $? -ne 0 ]; then
            echo assets:precompile failed.
            exit 1
        fi

        echo Reloading puma... && sudo service puma reload
        if [ $? -ne 0 ]; then
            echo Puma reload failed.
            exit 1
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

echo Fetching latest from origin... && git fetch origin
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

tag=`date "+deploy-%Y-%m-%d-%H-%M"`
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
echo Taking down maintenance page... && rm -f public/maintenance.html && \
echo Tagging repo with $tag... && git tag $tag && \
echo Pushing new tag... && git push --tags && \
echo SUCCESS\!

if [ $? -ne 0 ]; then
    echo ""
    echo "Deploy failed. Restarting puma and solidqueue with existing code..."
    sudo service puma start
    sudo service solidqueue start
    echo Resuming queues... && bundle exec rails runner script/resume_jobs.rb
    exit 1
fi
