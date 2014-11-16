# PIONE webclient

PIONE webclient is a web frontend for PIONE.

## Install

Run the following from terminal.

```
wget -q -O - https://raw.githubusercontent.com/pione/pione-webclient/master/install.sh | sh
```

## Run

### Production mode

    cd pione-webclient
    bundle exec god -c misc/pione-webclient.god

### Development mode

    cd pione-webclient
    bundle exec forman start

## How to setup Drop-ins app key

    % echo \$APP_KEY > dropins-app-key.txt

