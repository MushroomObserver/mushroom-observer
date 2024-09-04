# Install `puma-dev` for a local development environment

[Puma-dev](https://github.com/puma/puma-dev) provides an SSL and domain name for the local environment, making it more like production.

### Linux & MacOS instructions
- Stop your local rails server, if it's running
- Run `brew install puma/puma/puma-dev`
- Check OS specific [further installation and setup](https://github.com/puma/puma-dev?tab=readme-ov-file#installation).
  - On MacOS, it's very simple
    - `sudo puma-dev -setup`
    - `puma-dev -install`
  - Linux is a bit more involved, but not too.
    - It seems to be worth setting up a `systemd` service to run it in the background.
- Run `puma-dev link -n mushroomobserver ~/path-to-your-local-mushroom-observer-repo-folder`. This simply sets up a symlink from your new `~/.puma-dev` directory, to your directory for MO. Puma-dev will resolve any symlinks in that directory, using the name of the link as a domain. The first arg ("mushroomobserver") means it will resolve URLs at that domain, plus puma-dev's default TLD ("test"), to the given directory: it will serve MO (with or without SSL) at that address. (With further configuration, we could have it refuse or re-route non HTTPS requests, for testing.)
- Restart your machine
- Start `rails s` as you normally would
- In another window, run `ping mushroomobserver.test`. You should get responses every second.
