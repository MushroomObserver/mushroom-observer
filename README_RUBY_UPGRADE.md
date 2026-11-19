# Upgrading Ruby

`.ruby-version` holds the Ruby that MO runs, locally, in CI and on
production. This document is the procedure for moving it to a new
version. It names no version, so it stays current from one upgrade to
the next; read the pin with `cat .ruby-version` wherever a command
below says `<version>`.

## What an upgrade changes

- `.ruby-version`
- `Gemfile.lock` — its `RUBY VERSION` line, rewritten by `bundle install`
  under the new Ruby
- `Dockerfile` — the `ruby:<version>-bookworm` base image

CI reads `.ruby-version` through `ruby/setup-ruby`, so the workflows
need no change.

## Local development

### chruby

1. Install the new Ruby. This takes several minutes.

```sh
ruby-install ruby <version>
```

2. Confirm your shell profile sources chruby's auto-switcher, so that
   entering the project directory selects the pinned version:

```sh
source /opt/homebrew/share/chruby/chruby.sh
source /opt/homebrew/share/chruby/auto.sh
```

Intel Macs and Linux install chruby under `/usr/local/share/chruby`
instead.

3. Open a **new shell** in the project directory and check what the
   auto-switcher selected:

```sh
ruby --version
```

4. Install RubyGems and bundler for the new Ruby. chruby points
   `GEM_HOME` at a directory named for the full version
   (`~/.gem/ruby/<version>`), so a new Ruby starts with no gems,
   bundler included. The version to install is the one
   `Gemfile.lock`'s `BUNDLED WITH` names.

```sh
gem update --system
gem install bundler
```

5. Install the gems. Every native extension is compiled here, which
   takes a few minutes:

```sh
bundle install
```

6. Run the suite from a **new shell**:

```sh
bin/rails test
```

### rbenv

1. Teach ruby-build about the new version, install it, and let
   `.ruby-version` select it:

```sh
brew upgrade ruby-build
rbenv install <version>
```

2. From a **new shell** in the project directory, the steps are the
   chruby ones from step 4 on: `gem update --system`,
   `gem install bundler`, `bundle install`, `bin/rails test`.

## Production

Production runs chruby with its Rubies under `/opt/rubies`. Step 1 can
run days ahead of the deploy: the running puma holds the old Ruby and
keeps serving from it, and gems sit in a directory named for the
version, so nothing the new Ruby installs disturbs the site.

1. Install the Ruby as root, ahead of time:

```sh
ssh mushroomobserver.org
sudo su -
ruby-install ruby <version> -i /opt/rubies/ruby-<version>
```

2. Once the PR is merged, pull it and build the gems. `script/deploy.sh`
   runs `bundle exec` before it pulls or bundles anything, so the new
   Ruby needs its gems in place before the deploy starts — and the
   `Gemfile` reads `.ruby-version`, so the pull has to come first for
   bundler to agree the two match:

```sh
sudo su mo
cd /var/web/mo
chruby ruby-<version>
git pull
bundle install
```

Read the output for errors and warnings before going on.

3. Deploy. The script checks the running Ruby against
   `origin/main:.ruby-version` and stops if they differ:

```sh
script/deploy.sh
```

Solid Queue's workers hold the Ruby they started under, so they come
back on the new one when the deploy restarts them.

## Retiring the Rubies an upgrade leaves behind

Before deleting a version of Ruby ensure that no tools are relying on
it.  These are typically mentioned in the .ruby-version.  If found
this useful for hunting down lingering directories that reference
old versions of Ruby:

```sh
find ~ -maxdepth 4 -name .ruby-version -not -path "*/node_modules/*" \
  -exec sh -c 'echo "$(tr -d "[:space:]" < "$1")  $1"' _ {} \;
```

The gems are the bulk of the space used by a version of Ruby, and they
normally do not sit inside the Ruby tree.  So removing a version of
Rubyinvolves both deleting the directory containing the executable and
the gems.

### Remove it

Keep the new version, and the one before it as the rollback path until
there is confidence in the new version.  On production the ruby builds
are stored in `/opt/rubies/ruby-<version>` and the gem are in
`/home/mo/.gem/ruby/<version>`.  It requires root level permissions to
fully delete a Ruby version.

```sh
sudo rm -rf /opt/rubies/ruby-<version> /home/mo/.gem/ruby/<version>
```

Locally it is the same pair of directories under the paths chruby uses
on a workstation:

```sh
rm -rf ~/.rubies/ruby-<version> ~/.gem/ruby/<version>
```

`ruby-install` also leaves the unpacked source and its tarball in
`~/src/ruby-<version>` — ~330MB each, needed by nothing once the
install has finished.

## Troubleshooting

### `configure: error: something wrong with LDFLAGS`

`ruby-install` inherits `LDFLAGS`, `CPPFLAGS` and `PKG_CONFIG_PATH`
from the shell, and configure rejects the whole variable when one path
in it is missing — a Homebrew keg that was upgraded or uninstalled
since the profile naming it was written. Build with the three dropped:

```sh
env -u LDFLAGS -u CPPFLAGS -u PKG_CONFIG_PATH ruby-install ruby <version>
```

### "Ignoring gem-X.Y.Z because its extensions are not built"

Gems in the `GEM_HOME` were compiled against a different Ruby. Rebuild
them and open a new shell:

```sh
gem pristine --all
```

This is the repair for a `GEM_HOME` shared between two Rubies. A
chruby upgrade usually starts from an empty one, where `bundle install`
compiles everything and `gem pristine` has nothing to do.

### macOS system Ruby is selected

Errors naming
`/System/Library/Frameworks/Ruby.framework/Versions/2.6/` mean the
shell found Apple's Ruby.

- **chruby:** source `chruby.sh` and `auto.sh` in the shell profile, as
  above, then open a new shell in the project directory.
- **rbenv:** put `eval "$(rbenv init -)"` in the shell profile, then
  open a new shell.

### `rails` runs under the previous Ruby

A stale binstub at `/usr/local/bin/rails` outlives the upgrade. Use
`bin/rails`, the project's binstub. `which rails` shows which one the
shell finds; it should resolve under the version manager.

### "Your Ruby version is X, but your Gemfile specified Y"

The `Gemfile` declares `ruby(File.read(".ruby-version").strip)`, so
this says the active Ruby and the pin disagree. Activate the pinned
version rather than editing the pin, unless moving the pin is the point
of what you are doing.
