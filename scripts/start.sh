#!/bin/bash

#perl scripts/update-config.pl $1 $2

exec /usr/sbin/apache2ctl -D FOREGROUND
