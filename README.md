# camap-hx

camap-hx est la partie Haxe du logiciel CAMAP

## Framework et librairies

camap-hx tourne sous le framework MVC 
[Sugoï](https://github.com/AliloSCOP/sugoi).

Il est codé en [Haxe 4.05](https://www.haxe.org) et est exécuté par une VM [Neko](https://nekovm.org) ( avec Apache via mod_neko )

Il utilise [Lix](https://www.npmjs.com/package/lix) pour installer les librairies et la bonne version du compilateur Haxe (équivalent de npm/nvm dans le monde nodejs)

L'ORM est [record-macros](https://github.com/HaxeFoundation/record-macros) et se branche sur une base MySQL (moteur innodb)

[Documentation technique sur camap-ts](https://github.com/CAMAP-APP/camap-ts)

## Support navigateur

Depuis 2024 la librairie en ligne polyfill.io a n'est plus en ligne, le site n'est donc actuellement plus compatible IE11 et anterieur.
Il faudrait envisager d'intégrer un autre polyfill (e.g. core-js, nécessitera un environnement de validation IE11) OU d'officialiser la suppression du support IE11.