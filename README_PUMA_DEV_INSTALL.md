# Install `puma-dev` for local development environment.

Puma-dev provides an SSL and domain name for the local environment, making it more like production.

### Linux & MacOS instructions
- run `brew install puma/puma/puma-dev`
- check OS specific [further installation and setup](https://github.com/puma/puma-dev?tab=readme-ov-file#installation).
  - On MacOS, it's very simple
    - `sudo puma-dev -setup`
    - `puma-dev -install`
  - Linux is a bit more involved, but not too. It seems to be worth setting up a `systemd` service to run it in the background.
- Both: run `puma-dev link -n mushroomobserver ~/path-to-your-local-mushroom-observer-repo-folder`. This simply sets up a symlink from your new `~/.puma-dev` folder to your folder for MO, and puma-dev resolves any symlinks in that directory using the name of the link as a domain. The first arg means it will resolve URLs at the domain ("mushroomobserver") with puma-dev's default TLD ("test") to the given directory; it will serve MO (with or without SSL) at that address.
- restart your machine
- start `rails s` as you normally would
- in another window, run `ping mushroomobserver.test`
