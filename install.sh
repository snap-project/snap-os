#!/bin/bash

# Install system dependencies
apt-get update
apt-get -y --no-install-recommends install gdm3 xorg curl build-essential git libc6-dev libx11-dev libxinerama-dev libgconf-2-4

# Fix "version GLIBC_2.14 not found" fix in Debian 7
#echo "deb http://ftp.fr.debian.org/debian testing main" >> /etc/apt/sources.list
#apt-get -y update
#apt-get -t testing install libc6-dev

# Install nodejs + npm
curl -sL https://deb.nodesource.com/setup | bash -
apt-get -y install nodejs

npm update npm -g

## Install NWM window manager
npm install nwm -g
mkdir -p /usr/share/xsessions
nwm --init > /usr/share/xsessions/nwm.desktop

snap_user=snap
if [ ! $( id "$snap_user" &>/dev/null ) ]; then
  adduser --system "$snap_user"
fi

# Install SNAP

cd /opt

git clone https://github.com/snap-project/snap snap
chown -R "$snap_user": .

cd snap
su - "$snap_user" -s /bin/bash -c "cd /opt/snap; git checkout develop"
su - "$snap_user" -s /bin/bash -c "cd /opt/snap; npm install"
su - "$snap_user" -s /bin/bash -c "cd /opt/snap; ./node_modules/.bin/grunt download"

# Create SNAP data directories

mkdir -p /var/lib/snap

cd /var/lib/snap
git clone https://github.com/snap-project/snap-apps apps
mkdir -p data

chown -R "$snap_user": /var/lib/snap

ln -s /var/lib/snap/apps /opt/snap/apps
ln -s /var/lib/snap/data /opt/snap/data

chmod -R a+rw /opt/snap/{themes,apps,data}

# Install apps deps
su - "$snap_user" -s /bin/bash -c "cd /opt/snap; npm run install-apps-deps"

# Configure SNAP to launch at session startup
cat << 'EOF' > /usr/lib/node_modules/nwm/nwm-user-sample.js
module.exports = function(dependencies) {

  // modules
  var NWM = dependencies.NWM,
      XK = dependencies.keysymdef,
      Xh = dependencies.Xh,
      child_process = require('child_process'),
      which = dependencies.which;

  // instantiate nwm and configure it
  var nwm = new NWM();

  // load layouts
  var layouts = dependencies.layouts;
  nwm.addLayout('tile', layouts.tile);
  nwm.addLayout('monocle', layouts.monocle);
  nwm.addLayout('wide', layouts.wide);
  nwm.addLayout('grid', layouts.grid);

  nwm.start(function() {
    var env = JSON.parse(JSON.stringify(process.env));
    env.NODE_ENV='production';
    var snap = child_process.spawn('/usr/bin/npm', ['start'], { cwd: '/opt/snap', env: env });
    snap.once('error', function(err) {
        console.error(err.stack);
        process.exit(1);
    });
    snap.stderr.pipe(process.stderr);
    snap.stdout.pipe(process.stdout);
  });

};
EOF
