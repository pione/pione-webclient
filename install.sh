#!/usr/bin/env bash

cat <<EOF
Installer for PIONE Webclient
=============================
EOF

# check bundler
which bundle > /dev/null 2>&1
if [ ! $? -eq 0 ];
then
    cat <<EOF

"bunlder" command not found in your machine. You need to install bundler first,
see http://bundler.io/.
EOF
    exit 1
fi

cat <<EOF

Git clone
---------

EOF

# git clone
git clone https://github.com/pione/pione-webclient.git
cd pione-webclient

# setup bundle
cat <<EOF

Bundler
-------

EOF
bundle install --path=vendor/bundle

# task
cat <<EOF

Rake Task
---------

EOF
bundle exec rake setup

# print message for Drop-ins app key
cat <<EOF

Note for Drop-ins API
---------------------

PIONE Webclient needs Drop-ins app key in production environment. If you don't
have it, you can get from "https://www.dropbox.com/developers/apps".

### How to setup Drop-ins app key

    % echo \$APP_KEY > dropins-app-key.txt

How to Start
------------

### with development environment

    % bundle exec foreman start -f misc/Procfile

### with production environment

    % bundle exec god -c misc/pione-webclient.god

Reporting Bugs
--------------

Report bugs or feature requests to PIONE's issue tracker
(https://github.com/pione/pione/issues).

*** INSTALL COMPLETED ***
EOF
