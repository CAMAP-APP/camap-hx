# Warning !

_style.css_, _style.css.map_, _style.min.css_, _style.min.css.map_, _bootstrap.min.css_ and _bootstrap.min.css.map_ are compiled files, you should never modify them directly. Instead, compile them as explained below.

# Compile SASS

In the theme folder modify the _style.scss_.
In the backend folder run **build:sass** to build style.min.css and **dev:sass** to build style.css

```
cd backend
npm run build:sass
npm run dev:sass
```

# Compile Bootstrap

The files _bootstrap.min.css_ and _bootstrap.min.css.map_ should remain mostyle stable. Those steps are required if you change values in the variables.less file so that there are taken into account in the bootstrap framework.

In the theme folder modify the _variables.less_.

1. Download Bootstrap 3.4.1
   https://github.com/twbs/bootstrap/archive/v3.4.1.zip
2. Extract it and open it

```
cd bootstrap-3.4.1
```

3. Install dependencies

```
npm install
```

4. Copy the content of a variables.less to /bootstrap-3.4.1/less/variables.less

```
variables.less is in the theme folder e.g. /www/theme/default/css/variables.less
```

5. In the bootstrap repo run grunt dist to compile

```
grunt dist
```

6. Copy the generated files (bootstrap.min.css and bootstrap.min.css.map) to the theme folder

```
from /bootstrap-3.4.1/dist/css to /theme/default/css
```

More infos :

https://getbootstrap.com/docs/3.3/getting-started/#grunt

# Version InterAMAP44 de Camap - default style

Dans le style par défaut développé par InterAMAP44, la configuration est dans `style.scss` et `variable.less` afin d'être davantage compatible avec bootstrap. Le fichier `variable.scss` est recréé par ce script à partir de `variable.less`, et importé automatiquement par `style.scss`.

Les fichiers à modifier sont donc `/www/theme/default/css/variable.less` et `/www/theme/default/css/style.scss`

Ensuite le fichier `/www/theme/default/css_compile.sh` génère les fichiers de style avec bootstrap et les replace dans le répertoire /www/theme/default/css/
