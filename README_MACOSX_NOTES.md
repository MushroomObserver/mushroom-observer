The following is the beginning of a native MacOSX setup script.
It is based on @mo-nathan's notes while getting his local Apple M1
working under the Monterey (12.4) version of MacOS.
It also includes some notes later added by @nimmolo, and by
@JoeCohen when getting his local Apple Intel working under MacOS Ventura 13.6

### Install Xcode

Get Xcode (free download from the [App Store](https://www.apple.com/app-store/))

### Install Xcode Command Line Tools

install the command line tools with:

```sh
xcode-select --install
```

### Install homebrew

You will also need `homebrew` from <https://brew.sh/>:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

If you already have `homebrew` installed you may want to do:

```sh
brew outdated
brew upgrade
```

#### Important:
If you have mysql < 9.0 installed remove mysql and all vestiges before continuing.

- `ps -ax | grep mysql`
- stop and kill any MySQL processes
- `brew remove mysql`
- `brew cleanup`
- `sudo rm /usr/local/mysql`
- `sudo rm /etc/my.cnf`
- `sudo rm /usr/local/etc/my.cnf`
- `sudo rm -rf /usr/local/var/mysql`
- `sudo rm -rf /usr/local/mysql*`
- `sudo rm ~/Library/LaunchAgents/homebrew.mxcl.mysql.plist`
- `sudo rm -rf /Library/StartupItems/MySQLCOM`
- `sudo rm -rf /Library/PreferencePanes/My*`
- edit /etc/hostconfig and remove the line `MYSQLCOM=-YES-`
- `rm -rf ~/Library/PreferencePanes/My*`
- `sudo rm -rf /Library/Receipts/mysql*`
- `sudo rm -rf /Library/Receipts/MySQL*`
- `sudo rm -rf /private/var/db/receipts/*mysql*`

Install a bunch of useful stuff from `Homebrew`

```sh
brew install git mysql exiftool libjpeg shared-mime-info openssl imagemagick findutils
```

### Install Bash

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

### Configure MySQL

Set the root password

```sh
brew services start mysql
mysqladmin -u root password 'root'
```

Test the New Password: Verify that the new root password is working:

```sh
mysql -u root -p
```

When prompted, enter the new root password.
You should be able to access MySQL with the new password.

### Clone the MO repo.

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

### Switch to the cloned repo

```sh
cd mushroom-observer
```

### Make sure you have the current version of Ruby

```sh
if ! [[ `ruby --version` =~ `cat .ruby-version` ]]; then
    echo You need to install version `cat .ruby-version` of ruby
fi
```

There are various tools for this (rvm, chruby, rbenv).
In the past MO used rvm, but it caused havoc on the vm.
We recently switched to rbenv.
@mo-nathan used chruby most recently
because it was already installed.
For chruby, run:

```sh
ruby-build $RUBY_VERSION ~/.rubies/ruby-$RUBY_VERSION
   chruby $RUBY_VERSION
```

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

### Load an MO database snapshot.

- download the snapshot from <http://images.mushroomobserver.org/checkpoint_stripped.gz>
- copy (or move) the downloaded .gz file to the `mushroom-observer` directory.
Then:

Mac users have to uncomment/comment the relevant/irrelevant lines in `config/database.yml`:

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

NOTE: 2024-12-27 @JoeCohen: For me (but not others) `rake db:drop` threw an error
because `config/database.yml` was missing.
Please contact us if that is the case.

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

### Run the rest of the mo-dev script

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

### Continue the mo-dev script

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

Hopefully this is not necessary on a fresh clean system,
but @mo-nathan had to run

```sh
gem pristine --all
```

for each version of Ruby in chruby

### Prevent commits directly to the main branch

Create a file `.git/hooks/pre-commit` with the following content:

```sh
#!/bin/sh
branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$branch" = "main" ]
then
    echo "Do not commit directly to the $branch branch"
    exit 1
fi
```

Ensure that the file is executable:

```sh
chmod +x .git/hooks/pre-commit
```

### Ruby upgrade with chruby

Install the selected version.

  ruby-install ruby 3.3.6

Once that succeeds, update Ruby versions in .ruby-version and
Gemfile.lock.

In a new shell run:

  chruby ruby-3.3.6
  bundle install
  gem pristine --all

In another new shell now run:

  rails t

### Other

You probably need to generate a new development master key (see below)
if you get a test failure like this:

```txt
 FAIL ConfigTest#test_secrets (24.96s)
    Expected: "magic"
     Actual: nil
    test/models/config_test.rb:9:in `test_secrets'
```

@JoeCohen had to generate a new developmemt master key.
In the mushroom-observer directory, create the file
`/config/master.key` with this content:

```txt
5f343cfc11a623c470d23e25221972b5
```
