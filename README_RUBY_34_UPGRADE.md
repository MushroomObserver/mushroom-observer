# Upgrading to Ruby 3.4.9

This document covers upgrading from Ruby 3.3.6 to Ruby 3.4.9 for both
local development and production.

## Background

Ruby 3.3 has a compilation issue with recent versions of Xcode and the
trilogy gem. Ruby 3.4 resolves this. See
[Issue #4072](https://github.com/MushroomObserver/mushroom-observer/issues/4072).

## Local Development Upgrade

### Prerequisites

Make sure you have pulled the latest code from `main` (which already
contains the updated `.ruby-version` and `Gemfile.lock`).

### chruby

1. Install Ruby 3.4.9:

```sh
ruby-install ruby 3.4.9
```

This takes several minutes. If you encounter Xcode-related compilation
errors on macOS, make sure your Xcode Command Line Tools are up to date:

```sh
xcode-select --install
```

2. Ensure your shell profile sources chruby's auto-switcher
   (typically in `~/.zshrc` or `~/.bash_profile`):

```sh
source /usr/local/share/chruby/chruby.sh
source /usr/local/share/chruby/auto.sh
```

On Apple Silicon Macs with Homebrew, the paths may be:

```sh
source /opt/homebrew/share/chruby/chruby.sh
source /opt/homebrew/share/chruby/auto.sh
```

3. Open a **new shell** and `cd` to the project directory. chruby's
   auto-switcher will read `.ruby-version` and select Ruby 3.4.9
   automatically. Verify:

```sh
cd ~/src/mushroom-observer
ruby --version
```

You should see `ruby 3.4.9` in the output.

4. Update RubyGems and install bundler:

```sh
gem update --system
gem install bundler
```

5. Rebuild native extensions for all gems. This is necessary because
   gems with C extensions built under Ruby 3.3 are not compatible with
   Ruby 3.4:

```sh
gem pristine --all
```

You may see "Ignoring ..." warnings until this completes. These
warnings are caused by default gems (bigdecimal, stringio, date, etc.)
that shipped with Ruby 3.3 having extensions compiled for that version.
`gem pristine --all` rebuilds them for 3.4.

6. Install gems:

```sh
bundle install
```

7. Open a **new shell**, `cd` to the project directory, and verify
   the test suite passes:

```sh
cd ~/src/mushroom-observer
bin/rails test
```

### rbenv

1. Update ruby-build so it knows about 3.4.9:

```sh
brew upgrade ruby-build
```

2. Install Ruby 3.4.9:

```sh
rbenv install 3.4.9
```

rbenv will automatically use 3.4.9 for this project because
`.ruby-version` is already set.

3. Open a **new shell**, `cd` to the project directory, then verify:

```sh
cd ~/src/mushroom-observer
ruby --version
```

4. Update RubyGems and install bundler:

```sh
gem update --system
gem install bundler
```

5. Rebuild native extensions and install gems:

```sh
gem pristine --all
bundle install
```

6. Open a **new shell** and verify the test suite passes:

```sh
cd ~/src/mushroom-observer
bin/rails test
```

## Production Upgrade

Production uses chruby with Ruby installed to `/opt/rubies/`.
These steps are designed so that the production server continues
running on Ruby 3.3 until the final deploy restarts it.

1. **Pre-install** Ruby 3.4.9 on the server (can be done well ahead
   of the deploy):

```sh
ssh mushroomobserver.org
sudo su -
ruby-install ruby 3.4.9 -i /opt/rubies/ruby-3.4.9
```

2. **Pre-build gems** for Ruby 3.4.9. This is safe to do while
   production is still running on Ruby 3.3 because gems are stored
   in version-specific directories:

```sh
sudo su mo
chruby ruby-3.4.9
gem update --system
gem install bundler
gem pristine --all
```

3. **Deploy.** Once the PR is merged, activate Ruby 3.4.9 and run
   the deploy script. The script will verify the Ruby version matches
   `origin/main:.ruby-version`, pull the latest code, and run
   `bundle install`:

```sh
sudo su mo
cd /var/web/mo
chruby ruby-3.4.9
script/deploy.sh
```

## Changes in the PR

The following files are updated as part of this upgrade:

- `.ruby-version` — `3.3.6` → `3.4.9`
- `Gemfile.lock` — regenerated with Ruby 3.4.9
- `README_MACOSX_NOTES.md` — version references updated
- `README_PRODUCTION_RUBY_UPGRADE` — version reference updated

CI (`ruby/setup-ruby`) reads `.ruby-version` automatically, so no
workflow changes are needed.

## Troubleshooting

### "Ignoring gem-X.Y.Z because its extensions are not built"

Run `gem pristine --all` to rebuild native extensions for the new
Ruby version. Open a new shell afterward.

### System Ruby is used instead of 3.4.9

If you see errors referencing
`/System/Library/Frameworks/Ruby.framework/Versions/2.6/`, your shell
is using macOS system Ruby instead of the chruby/rbenv-managed version.

- **chruby:** Make sure `chruby.sh` and `auto.sh` are sourced in your
  shell profile (see step 8 under chruby above). Then open a new shell
  and `cd` to the project directory.
- **rbenv:** Make sure `eval "$(rbenv init -)"` is in your shell
  profile. Then open a new shell.

### `rails` runs system Ruby instead of 3.4.9

After a Ruby upgrade, a stale `rails` binstub at `/usr/local/bin/rails`
may still point to the old system Ruby. Always use `bin/rails` (the
project-relative binstub) instead of bare `rails`. You can verify which
`rails` your shell finds with `which rails` — it should point to a path
under your Ruby version manager, not `/usr/local/bin/rails`.

### "Your Ruby version is X, but your Gemfile specified Y"

Update `.ruby-version` to match the Ruby you have active:

```sh
echo "3.4.9" > .ruby-version
```

Then run `bundle install` again.

## Ruby 3.4 Notable Changes

For the full list, see the
[Ruby 3.4.0 release notes](https://www.ruby-lang.org/en/news/2024/12/25/ruby-3-4-0-released/).

Key items relevant to MO:

- **`it` as block parameter reference** — `it` is now a keyword that
  refers to the first block parameter. If MO uses `it` as a local
  variable name inside a block, Ruby 3.4 will emit a warning. The fix
  is to rename the variable.
- **Frozen string literals** — no change in default yet, but Ruby 3.4
  adds `# frozen_string_literal: true` warnings in more places. MO
  already uses this pragma in all files.
- **Default gems promoted to bundled gems** — `rdoc` and `irb` are
  now bundled gems. This should not affect MO since we do not depend
  on them directly in the Gemfile.
