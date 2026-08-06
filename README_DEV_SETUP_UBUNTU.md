# Setup Ubuntu Linux Development Environment

## Create an Fresh Ubuntu Box

This has been tested with Ubuntu 25.04 x64 on the Digital Ocean cloud,
but should work with any reasonably recent version of Ubuntu Linux and
potentially other Linux distros that support `apt`.

MO currently uses the Digital Ocean (DO) cloud, but this you should be
able to test this by creating a fresh Ubuntu Droplet follow these
steps:
- Click "Create" -> "Droplet"
- Options I selected: New York, CPU Regular, $12/mo (2GB RAM, 1 CPU,
50GB SSD, 2TB transfer).  This was the minimal configuration I could
get to work.  Selecting more and better CPUs will probably
significantly decrease the time needed to configure the system and run
the tests.  By way of comparison, the tests took about 15 minutes to
run with those options.  However, on my local systems (a recent
MacBook Pro) they take under 3 minutes.
- Use an SSH Key you have the private key for or create a new one and upload it to DO
- Add improved metrics monitoring and alerting (might now be on by default)
- Click "Create Droplet"

Shortly after I was able to access the web-based console from the DO UI

# Run dev_setup_ubuntu
I don't recommend running straight from a web console due to
potential timeouts.  Better to run screen.  Note that the -L option
puts all the output in a file in the root home directory which can be
reviewed for errors.  From the web-based console run `screen -L`.

On any freshly built Ubuntu box, logged in as root, you should be able
to run:

```sh
  curl -s https://raw.githubusercontent.com/MushroomObserver/mushroom-observer/HEAD/script/dev_setup_ubuntu | bash
```

This does the one-time root-level system prep (creates the `mo` user,
installs system packages, chruby, ruby-install), then automatically
continues as `mo` to clone the repo, set up Ruby/gems/the database,
and run the test suite -- one command instead of two.

It may prompt you to set a password for `mo` partway through (needed
for `mo` to `sudo` in the steps after that) if one isn't set yet.
That prompt works fine if you downloaded the script to a file first
(`curl -o dev_setup_ubuntu ... && bash dev_setup_ubuntu`); if you ran
the one-liner above via a raw pipe, the prompt may not read your input
correctly (a well-known limitation of interactive prompts inside a
`curl | bash` pipe -- the prompt reads from the same stdin bash is
still consuming as script source). If that happens, set the password
yourself and re-run as `mo`:

```sh
  passwd mo
  sudo su - mo
  curl -s https://raw.githubusercontent.com/MushroomObserver/mushroom-observer/HEAD/script/dev_setup_ubuntu | bash
```

Or ssh in as the mo user from any system that has the key for any
public key installed when the droplet was created, using the IP
address of the droplet:

```sh
  ssh mo@<ip>
```

This has only actually been tested on a DO droplet as described
above. Open a GitHub issue if you run into issues with recent Ubuntu
systems.  It is also very conceivable that this will "just work" on
other Linux distro that support `apt`.

At the end of the mo phase, it runs the entire test suite, which
should pass with no errors or failures.

# Fragment caching in development

Rails' fragment/low-level caching is off by default in development
(`config.action_controller.perform_caching = false`) so that editing
a view always shows your latest change instead of a stale cached
fragment. Run `bin/rails dev:cache` to toggle it on (creates
`tmp/caching-dev.txt`); run it again to toggle back off.

When it's on, the cache store is Solid Cache (the `cache_development`
database), matching production — not an in-process memory store — so
a cache read/write costs a real query locally too, same as prod.

MO's fragment-caching call site, `Components::Matrix::Table` (the
observations/images grid), keys its fragments on a hand-maintained
`CACHE_VERSION` string (see `app/components/matrix/table.rb`), not
automatic template-digest busting. If you're editing `Matrix::Box`'s
rendering with caching toggled on, remember to bump `CACHE_VERSION`
or you'll see stale HTML for previously-cached rows.

Because the store is a real database table now, neither restarting
the server nor toggling `bin/rails dev:cache` off and back on clears
it (`dev:cache`'s only side effect is `tmp:clear`, which doesn't touch
`cache_development`). If you need a clean slate -- e.g. you forgot to
bump `CACHE_VERSION` and want to confirm that's really the cause --
run `Rails.cache.clear` from `bin/rails console`.
