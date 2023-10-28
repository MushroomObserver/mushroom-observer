The following is the beginning of a native MacOSX setup script.
It is based on the notes @nimmolo took while getting his local Apple M1
working under the Monterey (12.4) version of MacOS.
It also includes some notes later added by @JoeCohen when getting his
local Apple Intel working under MacOS Ventura 13.6

### Install bash
You will need to get Xcode (free download from the App Store) and
install the command line tools with:
```sh
xcode-select --install
```

### Install homebrew
You will also need `homebrew` from https://brew.sh/:
```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
If you already have `homebrew` install you may want to do:
```sh
brew outdated
brew upgrade
```

Install a bunch of useful stuff from `Homebrew`
```sh
brew install git mysql exiftool libjpeg shared-mime-info openssl imagemagick findutils
```
### Install bash
If you haven't done so already, install a more recent version of `bash` and set
it as the default. You can find your installed version like this:
```sh
bash --version
```
Apple only includes `Bash` 3.2 from 2007 in all versions of Mac OS X even now,
because `Bash` > 4.0 uses GPLv3, and they don't want to support that license.
MO's scripts use syntax that requires `Bash` >= 4.0.
Description of the script error that occurs if you aren't running newer `Bash`:
https://stackoverflow.com/questions/6047648/associative-arrays-error-declare-a-invalid-option
To install the newest `Bash` alongside older versions:
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
/usr/local/bin/bash --version
/bin/bash --version
```
now check
```sh
/usr/local/bin/bash --version
```
should be the new one.

### Configure MySQL
Set the root password
```sh
brew services start mysql
mysqladmin -u root password 'root'
```

@JoeCohen had problems setting the MySQL root password
as follows:
```sh
~ % mysqladmin -u root password 'root'
mysqladmin: connect to server at 'localhost' failed
error: 'Access denied for user 'root'@'localhost' (using password: NO)'
```
He used this solution (from ChatGPT, explanations omitted)
1. Stop MySQL Server
```sh
brew services stop mysql
```
2. Start MySQL in Safe Mode
```sh
mysqld_safe --skip-grant-tables
```
3. Open a New Terminal Window
4. In the new terminal window, access MySQL as Root without a password:
```sh
mysql -u root
```
5. Inside the MySQL prompt, update the root password:
```sql
USE mysql;
UPDATE user SET authentication_string=PASSWORD('root') WHERE User='root';
FLUSH PRIVILEGES;
exit;
```
6. Stop Safe Mode MySQL Server:
In the original terminal window where you started the MySQL server in safe mode, press Ctrl C to stop the server.
7. Restart MySQL
```sh
brew services start mysql
```
Test the New Password: Verify that the new root password is working:
```sh
mysql -u root -p
```
When prompted, enter the new root password.
You should be able to access MySQL with the new password.

### Clone the MO repo and switch to it.
Make sure you have an update to checkout of this repo in a local directory.
Since you're reading this you may have already done that.
In case you haven't run:
```sh
git clone git@github.com:MushroomObserver/mushroom-observer.git
cd mushroom-observer
```

### Make sure you have the current version of Ruby.
```sh
if ! [[ `ruby --version` =~ `cat .ruby-version` ]]; then
    echo You need to install version `cat .ruby-version` of ruby
fi
```

There are various tools for this (rvm, chruby, rbenv).
In the past MO used rvm, but recently switched to rbenv.
@nimmolo used chruby most recently
because it was already installed.
For chruby you need to run:
```sh
ruby-build $RUBY_VERSION ~/.rubies/ruby-$RUBY_VERSION
   chruby $RUBY_VERSION
```

@JoeCohen used rbenv. He had to modify the shell configuration to
give priority to rbenv, by adding the following to both `.bashrc`
(and just for safety, to `.zshrc`).
```sh
if which rbenv > /dev/null; then
  eval "$(rbenv init -)"
fi
```

### Install an MO database snapshot.
- download the snapshot from http://images.mushroomobserver.org/checkpoint_stripped.gz
- copy (or move) the downloaded .gz file to the mushroom-observer directory
Then
```sh
rake db:drop
mysql -u root -p < db/initialize.sql
Enter password:
```
Enter `root` return
```sh
gunzip -c checkpoint_stripped.gz | mysql -u mo -pmo mo_development
rails lang:update
rails db:migrate
```
Then delete `checkpoint_stripped.gz` from the mushroom-observer directory

### Run the rest of the mo-dev script
(See https://github.com/MushroomObserver/developer-startup/blob/main/mo-dev)
(Both @nimmolo and @JoeCohen did this in pieces.)
Open a new shell and run
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
### Install mysql2
@nimmolo needed to run the following to get the `mysql2`` gem to install.
Your mileage may vary...
```sh
gem install mysql2 -v '0.5.3' -- --with-opt-dir=$(brew --prefix openssl) --with-ldflags=-L/opt/homebrew/opt/zstd/lib
bundle config --global build.mysql2 "--with-opt-dir=$(brew --prefix openssl) --with-ldflags=-L/opt/homebrew/opt/zstd/lib"
```
JoeCohen just did:
```sh
gem install mysql2
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
rm config/credentials.yml.enc
EDITOR='echo "test_secret: magic" >> ' rails credentials:edit
```

Hopefully this is not necessary on a fresh clean system,
but @nimmolo had to run
```sh
gem pristine --all
```
for each version of Ruby in chruby
