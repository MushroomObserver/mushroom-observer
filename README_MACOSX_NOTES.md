Setup MacOSX Development Environment

This the start of a native MacOSX setup script.
It is based on @mo-nathan's notes for his local Apple M1 with MacOS Monterey (12.4).
It includes notes later added by @nimmolo, and by
@JoeCohen for his local Apple Intel with MacOS Ventura 13.6
though Sequoia 15.2.

- [Install Needed Tools](#install-needed-tools)
  - [Xcode](#xcode)
  - [Xcode Command Line Tools](#xcode-command-line-tools)
  - [homebrew](#homebrew)
    - [WARNING: Older macOS or Mac hardware](#warning-older-macos-or-mac-hardware)
  - [Install a bunch of useful stuff from Homebrew](#install-a-bunch-of-useful-stuff-from-homebrew)
    - [WARNING: Previously Installed Versions Of MySQL](#warning-previously-installed-versions-of-mysql)
  - [Bash](#bash)
  - [Configure MySQL](#configure-mysql)
      - [IMPORTANT](#important)
- [Obtain and configure MO](#obtain-and-configure-mo)
  - [Clone the MO repo](#clone-the-mo-repo)
  - [Switch to the cloned repo](#switch-to-the-cloned-repo)
  - [Make sure you have the current version of Ruby](#make-sure-you-have-the-current-version-of-ruby)
    - [chruby](#chruby)
    - [rbenv](#rbenv)
    - [Load an MO database snapshot](#load-an-mo-database-snapshot)
  - [Run the rest of the mo-dev script](#run-the-rest-of-the-mo-dev-script)
    - [Install trilogy](#install-trilogy)
  - [Continue the mo-dev script](#continue-the-mo-dev-script)
  - [Prevent direct commits to the main branch](#prevent-direct-commits-to-the-main-branch)
  - [Ruby upgrade with chruby](#ruby-upgrade-with-chruby)
  - [Other](#other)
- [Footnotes](#footnotes)

<small><i><a href='http://ecotrust-canada.github.io/markdown-toc/'>Table of contents generated with markdown-toc</a></i></small>

# Install Needed Tools

## Xcode

Get Xcode (free download from the [App Store](https://www.apple.com/app-store/))

## Xcode Command Line Tools

install the command line tools with:

```sh
xcode-select --install
```

## homebrew

### WARNING: Older macOS or Mac hardware

**Do not update Homebrew or MySQL if you have older hardware or macOS < 11.
MySQL 9 will not install in any case on older Macs.**


You will also need `homebrew` from <https://brew.sh/>:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

If you already have `homebrew` installed you may want to do:

```sh
brew outdated
brew upgrade
```

## Install a bunch of useful stuff from Homebrew

### WARNING: Previously Installed Versions Of MySQL

**If you have mysql version < 9.0 installed, remove mysql and all its vestiges before
continuing. See footnote 1.<sup id="a1">[1](#f1)</sup>**


```sh
brew install git mysql exiftool libjpeg shared-mime-info openssl imagemagick findutils
```

## Bash

If you haven't done so already, install a recent version of [Bash](https://www.gnu.org/software/bash/) and set
it as the default shell. You can find your installed version like this:

```sh
bash --version
```

Apple includes only Bash 3.2 from 2007 in all versions of Mac OS X even now,
because Bash > 4.0 uses GPLv3, and they don't want to support that license.
MO's scripts use syntax that requires Bash >= 4.0.
Description of the script error that occurs if you aren't running newer Bash:
<https://stackoverflow.com/questions/6047648/associative-arrays-error-declare-a-invalid-option>
To install the newest Bash alongside older versions:

```sh
brew install bash
```

now check paths of all versions installed

```sh
which -a bash
```

You should get something like this

```sh
/usr/local/bin/bash
/bin/bash
```

Check those versions

```sh
/bin/bash --version
/usr/local/bin/bash --version
```

`/usr/local/bin/bash` should be the new one.

## Configure MySQL

Set the root password

```sh
brew services start mysql
mysqladmin -u root password 'root'
```

#### IMPORTANT

> If you cannot set the mysql root password, please contact us
> instead of applying random "solutions" from AI or StackOverflow.

Test the New Password: Verify that the new root password is working:

```sh
mysql -u root -p
```

When prompted, enter the new root password.
You should be able to access MySQL with the new password.

# Obtain and configure MO

## Clone the MO repo

Make sure you have an up-to-date checkout of this repo in a local directory.
Since you're reading this you may have already done that.
In case you haven't, run:

```sh
git clone git@github.com:MushroomObserver/mushroom-observer.git
```

@JoeCohen had to instead initially run

```sh
git clone https://github.com/MushroomObserver/mushroom-observer
```

## Switch to the cloned repo

```sh
cd mushroom-observer
```

## Make sure you have the current version of Ruby

```sh
if ! [[ `ruby --version` =~ `cat .ruby-version` ]]; then
    echo You need to install version `cat .ruby-version` of ruby
fi
```

There are various tools for this (rvm, chruby, rbenv).
We recently switched to rbenv.
(In the past MO used rvm, but it caused havoc on the vm.)
@mo-nathan used chruby most recently because it was already installed.

### chruby

For chruby, run:

```sh
  ruby-build $RUBY_VERSION ~/.rubies/ruby-$RUBY_VERSION
  chruby $RUBY_VERSION
```

### rbenv

@nimmolo and @JoeCohen used rbenv.
For rbenv run: (installing ruby-build maybe also needed above)

```sh
   brew install rbenv ruby-build
```

Add rbenv to zsh/bash so that it loads every time you open a terminal

```sh
   echo 'if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi' >> ~/.zshrc
   source ~/.zshrc
   rbenv install $RUBY_VERSION
   rbenv global $RUBY_VERSION
```

or for bash:

```sh
   echo 'if which rbenv > /dev/null; then eval "$(rbenv init - bash)"; fi' >> ~/.bash_profile
   source ~/.bash_profile
   rbenv install $RUBY_VERSION
   rbenv global $RUBY_VERSION
```

### Load an MO database snapshot

- Make sure you have the file `config/database.yml`.
  If not, create the file with the content shown in footnote 2.<sup id="a2">[2](#f2)</sup>

To get the most recent stripped checkpoint, which may not be at all current:
- download the snapshot from <http://images.mushroomobserver.org/checkpoint_stripped.gz>  
- copy (or move) the downloaded .gz file to the `mushroom-observer` directory.

OR, if you have access to the images server, you can get a current db backup and strip it yourself:
- download the most recent db backup. `yourname` is your account name on the images server, and `yyyymmdd` is yesterday's date.
```
scp {yourname}@images.mushroomobserver.org:/data/images/backup/database-{yyyymmdd}.gz /path/to/your/mushroom-observer/checkpoint.gz
```
- run `db/strip_checkpoint`. This will replace passwords and save the backup as `checkpoint_stripped.gz`.

Then:

Mac users must uncomment/comment the relevant/irrelevant lines in `config/database.yml`:

```yml
shared:
  adapter: trilogy
  # Default (works for MacOS X), uncomment this line
  socket: /tmp/mysql.sock
  # For Ubuntu/Debian, comment out this line
  # socket: /var/run/mysqld/mysqld.sock
```

Then:

```sh
rake db:drop
mysql -u root -p < db/initialize.sql
```

When prompted to "Enter password:" <br>
Enter `root`, return.
Then:

```sh
gunzip -c checkpoint_stripped.gz | mysql -u mo -pmo mo_development
rails lang:update
rails db:migrate
```

When @JoeCohen first installed the app (MacBook Pro, Intel, OSX 13.6),
`rails` was not recognized. He had to use `bin/rails` instead.
The next time he installed the app (same hw/sw) it recognized `rails`,
but gave this error:

```sh
% rails lang:update
rails aborted!
Cannot load database configuration:
Could not load database configuration. No such file - ["config/database.yml"]
```

which was fixed by running

```sh
cp db/macos/database.yml config
```

Optionally delete `checkpoint_stripped.gz` from the mushroom-observer directory

## Run the rest of the mo-dev script

(See <https://github.com/MushroomObserver/developer-startup/blob/main/mo-dev>)
(Both @nimmolo and @JoeCohen did this in pieces.)

- Open a new shell
- run:

```sh
gem install bundler

if [ ! -f config/database.yml ]; then
    cp db/macos/database.yml config
    echo Copied config/database.yml
else
    echo database.yml exists
fi

if [ ! -f config/gmaps_api_key.yml ]; then
    cp config/gmaps_api_key.yml-template config/gmaps_api_key.yml
    echo Copied config/gmaps_api_key.yml
else
    echo gmaps_api_key.yml exists
fi

for dir in images test_images;
  do
    for subdir in thumb 320 640 960 1280 orig;
    do
      if [ ! -d public/$dir/$subdir ]; then
        mkdir -p public/$dir/$subdir
        echo Created public/$dir/$subdir
      else
       echo public/$dir/$subdir exists
     fi
    done
  done

if [ ! -f /usr/local/bin/jpegresize ]; then
    sudo gcc script/jpegresize.c -I/opt/homebrew/include -L/opt/homebrew/lib -ljpeg -lm -O2 -o /usr/local/bin/jpegresize
    echo Created and installed jpegresize executable
else
    echo jpegresize exists
fi

if [ ! -f /usr/local/bin/exifautotran ]; then
    sudo cp script/exifautotran /usr/local/bin/exifautotran
    sudo chmod 755 /usr/local/bin/exifautotran
    echo Installed exifautotran script
else
    echo exifautotran exists
fi
```

### Install trilogy

```sh
gem install trilogy
```

## Continue the mo-dev script

```sh
git pull
bundle install

mysql -u mo -pmo mo_development -e ''
if [ ! $? -eq 0 ]; then
    mysql -u root -proot < db/initialize.sql
    bin/rails db:environment:set RAILS_ENV=development
    rails db:schema:load
    rails db:fixtures:load
    echo Created and populated mo_development database
else
    rails db:migrate
    echo Ran migrations on the mo_development database
fi

rails lang:update
# nimmo says: don't run the next two lines.
#   The encrypted credentials.yml.enc file in the GitHub repo is correct
#   and necessary. Rails credentials require a copy of the master.key
#   in order to use it, available via email from any MO developer.
rm config/credentials.yml.enc
EDITOR='echo "test_secret: magic" >> ' rails credentials:edit
```

Hopefully this is not necessary on a fresh clean system, but
@mo-nathan had to run the following for each version of Ruby in chruby.

```sh
  gem pristine --all
```

## Prevent direct commits to the main branch

> Create a file `.git/hooks/pre-commit` with the following content:

```sh
  #!/bin/sh
  branch=$(git rev-parse --abbrev-ref HEAD)
  if [ "$branch" = "main" ]
  then
    echo "Do not commit directly to the $branch branch"
    exit 1
  fi
```

> Ensure that the file is executable:

```sh
  chmod +x .git/hooks/pre-commit
```

## Ruby upgrade with chruby

- Install the selected version.

```sh
  ruby-install ruby 3.3.6
```

- Once that succeeds, update Ruby versions in `.ruby-version` and `Gemfile.lock`.
- In a new shell run:

```sh
  chruby ruby-3.3.6
  bundle install
  gem pristine --all
```

- In another new shell now run:

```sh
  rails t
```

## Other

You probably need to generate a new development master key (see below)
if you get a test failure like this:

```sh
  Stopped processing SimpleCov as a previous error not related to SimpleCov has
  been detected ... inat_imports_controller.rb:50:in
  <class:InatImportsController>: undefined method id for nil (NoMethodError)
```

or like this:

```ruby
 FAIL ConfigTest#test_secrets (24.96s)
    Expected: "magic"
     Actual: nil
    test/models/config_test.rb:9:in `test_secrets'
```

To generate a new developmemt master key.
In the `mushroom-observer` directory, create the file
`config/master.key` with this content:

```txt
5f343cfc11a623c470d23e25221972b5
```

-----

# Footnotes

<b id="f1">1.</b> Suggested procedure for removing vestiges of mysql [↩](#a1)

- `ps -ax | grep mysql`
- stop and kill any MySQL processes
- `brew remove mysql`
- `brew cleanup`
- `sudo rm /.my.cnf`
- `sudo rm /.mysql_history`
- `sudo rm /etc/my.cnf`
- `sudo rm /usr/local/etc/my.cnf.default`
- `sudo rm -rf /usr/local/etc/my.cnf`
- `sudo rm -rf /usr/local/var/mysql`
- `sudo rm -rf /usr/local/mysql*`
- `sudo rm ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist`
- `sudo rm -rf /Library/StartupItems/MySQLCOM`
- `sudo rm -rf /Library/PreferencePanes/My*`
- `rm -rf ~/Library/PreferencePanes/My*`
- `sudo rm -rf /Library/Receipts/mysql*`
- `sudo rm -rf /Library/Receipts/MySQL*`
- `sudo rm -rf /private/var/db/receipts/*mysql*`
- edit /etc/hostconfig and remove the line `MYSQLCOM=-YES-`

<b id="f2">2.</b>  Content of `/config/database.yml` [↩](#a2)

```yml
# This file should not be checked into subversion

# MySQL (default setup).
#
# Get the fast C bindings:
#   gem install trilogy
#   (on OS X: gem install mysql -- --include=/usr/local/lib)

shared:
  adapter: trilogy
  # Default (works for MacOS X)
  socket: /tmp/mysql.sock
  # For Ubuntu/Debian
  # socket: /var/run/mysqld/mysqld.sock
  # For Fedora
  # socket: /var/lib/mysql/mysql.sock
  # Connect on a TCP socket.  If omitted, the adapter will connect on the
  # domain socket given by socket instead.
  #host: localhost
  #port: 3306
  # For mysql >= 5.7.5
  # Do not require SELECT list to include ORDER BY columns in DISTINCT queries,
  # And do not not require ORDER BY to include the DISTINCT column.
  variables:
    sql_mode: TRADITIONAL

development:
  primary:
    database: mo_development
    username: mo
    password: mo
  cache:
    database: cache_development
    username: mo
    password: mo
    host: localhost
    migrations_paths: "db/cache/migrate"

# Warning: The database defined as 'test' will be erased and
# re-generated from your development database when you run 'rake'.
# Do not set this db to the same as development or production.
test:
  database: mo_test
  username: mo
  password: mo

production:
  database: mo_production
  username: mo
  password: mo
```
