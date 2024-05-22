#!/bin/bash
#
# Dans le style par défaut développé par InterAMAP44, la configuration a été déplacée de style.scss vers bootswatch.scss et variable.less
# afin d'être d'avantage compatible avec bootstrap. Le fichier style.scss est recréé par ce script à partir de bootswatch et variable
#
if [ $# -ne 1 ]
then
        echo "Vous devez préciser le répertoire d'installation de CAMAP"
        echo "ex: \"css_compile.sh /srv/data/CAMAP-TEST pour compiler les styles de /srv/data/CAMAP-TEST"
        exit 0
fi
CAMAPDIR=$1
cat $CAMAPDIR/camap-hx/www/theme/default/css/variables.less | grep -v keyframes |  sed s/@/$/g > $CAMAPDIR/camap-hx/www/theme/default/css/variables.scss
cd $CAMAPDIR/../bootstrap-3.4.1/
cp $CAMAPDIR/camap-hx/www/theme/default/css/variables.less less/variables.less
grunt dist
cp -f dist/css/bootstrap.*css* $CAMAPDIR/camap-hx/www/theme/default/css/
cd $CAMAPDIR/camap-hx/backend
npm run build:sass
cd $CAMAPDIR/camap-hx