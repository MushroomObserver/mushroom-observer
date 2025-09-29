# Setup Linux Development Environment

## Install on a new Digital Ocean (DO) droplet.
Create a new droplet with the latest version of Ubuntu.  At the time of this writing that is 25.04 x64.
- Options I selected: New York, CPU Regular, $12/mo (2GB RAM, 1 CPU, 50GB SSD, 2TB transfer)
- SSH Key (chosen only Nathan 2 since I have the private key for that you may want to add your own if not listed)
- Add improved metrics monitoring and alerting
- Click "Create Droplet"

Shortly after I was able to access the web-based console from the DO UI

# Install needed packages:
```sh
apt update
DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y upgrade

DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical apt -y install \
tcsh zsh man vim lynx telnet emacs wget build-essential \
bison libyaml-dev libxslt-dev mysql-server mysql-client \
libmysqlclient-dev libcurl4-openssl-dev libssl-dev libapr1-dev \
libaprutil1-dev libreadline-dev zlib1g-dev imagemagick \
libmagickcore-dev libmagickwand-dev libjpeg-dev libjpeg-progs \
libimage-exiftool-perl
```

# Create directory for MO source
```sh
mkdir /var/web
chmod 777 /var/web
```

# Create mo user:
```sh
useradd -m -G sudo -s /bin/zsh mo
passwd mo
sudo su mo
```
Will ask for zsh config.  Selecting "2" is the simplest thing to do.
However, I don't like the default `prompt adam1`, so I updated to `prompt walters`
which works better on black on white screens.

# Optionally configure SSH access as user mo
```sh
cd
mkdir .ssh
chmod 700 .ssh
touch .ssh/authorized_keys
```

# Copy a public key into .ssh/authorized_keys
```sh
exit
cat ~/.ssh/authorized_keys >> ~mo/.ssh/authorized_keys
sudo su mo
```

# Checkout MO source code
```sh
cd /var/web
git clone https://github.com/MushroomObserver/mushroom-observer.git
cd mushroom-observer
```

# Initial a bunch more stuff now that we have the MO code
I don't recommend running this from the web console due to potential
timeouts.  Better to login from a real terminal window and run screen
```sh
screen
cd /var/web/mushroom-observer
script/init_ubuntu
```
