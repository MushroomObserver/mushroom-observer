# Setup Linux Development Environment

## Install on a new Digital Ocean (DO) droplet.
Create a new droplet with the latest version of Ubuntu.  At the time of this writing that is 25.04 x64.
- Options I selected: New York, CPU Regular, $12/mo (2GB RAM, 1 CPU, 50GB SSD, 2TB transfer)
- SSH Key (chosen only Nathan 2 since I have the private key for that you may want to add your own if not listed)
- Add improved metrics monitoring and alerting
- Click "Create Droplet"

Shortly after I was able to access the web-based console from the DO UI

# Run ubuntu_setup_root
I don't recommend running straight from the web console due to
potential timeouts.  Better to run screen.  Note that the -L option
puts all the output in a file in the root home directory which can be
reviewed for errors.  From the web-based console run `screen -L`
followed by:

```sh
  curl -s https://raw.githubusercontent.com/MushroomObserver/mushroom-observer/njw-digitalocean-dev/script/ubuntu_setup_root | bash
```

# Set mo password
As root run so mo can sudo for the next phase:

```sh
  passwd mo
```

From the current shell you can now run:
```sh
  sudo su - mo
```

Or you should now be able to ssh in as the mo user from any system
that has the key for any public key installed when the droplet was
created using the IP address of the droplet.
```sh
  ssh mo@<ip>
```

# Run ubuntu_setup_mo
```sh
  screen -L
  curl -s https://raw.githubusercontent.com/MushroomObserver/mushroom-observer/njw-digitalocean-dev/script/ubuntu_setup_mo | bash
```
