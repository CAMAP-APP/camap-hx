# camap-hx

camap-hx est la partie Haxe du logiciel CAMAP

## Framework et librairies

camap-hx tourne sous le framework MVC 
[Sugoï](https://github.com/CagetteNet/sugoi).

Il est codé en [Haxe 4.05](https://www.haxe.org) et est exécuté par une VM [Neko](https://nekovm.org) ( avec Apache via mod_neko )

Il utilise [Lix](https://www.npmjs.com/package/lix) pour installer les librairies et la bonne version du compilateur Haxe (équivalent de npm/nvm dans le monde nodejs)

L'ORM est [record-macros](https://github.com/HaxeFoundation/record-macros) et se branche sur une base MySQL (moteur innodb)

## Templates

Les templates sont gérés avec la librairie [templo](https://github.com/ncannasse/templo) ( fichiers *.mtt )

Le développeur créé et modifie les templates dans `/lang/master/tpl` 

Les templates sont compilés en 2 passes :
 
1. le framework copie ces templates dans chaque dossier de langue (ex : /lang/fr/tpl) en traduisant les chaines de textes via des fichiers de traduction gettext (*.po et *.mo)
2. le framework compile le template en *.mtt.n dans le dossier /lang/fr/tmp 

En environnement de dev, mettez DEBUG=1 dans config.xml cela aura pour effet d'exécuter les 2 passes automatiquement et de voir directement le résultat des modifications de templates en local

En environnement de production, mettez DEBUG=0 pour gagner en performance.
Cela veut dire qu'il faut exécuter les 2 passes avant le déploiement.
Compiler l'app avec l'option i18n_generation pour l'étape 1 : 

```
haxe build.hxml -D i18n_generation
```
puis compilez les templates en *.mtt.n dans chaque dossier de `lang` pour l'étape 2
```
neko ../../../backend/temploc2.n -macros macros.mtt -output ../tmp/ *.mtt */*.mtt */*/*.mtt 
```




## i18n

Dans config.xml, "lang" permet de définir la langue par défaut, "langs" permet de définir la liste des langues disponibles, "langnames" définit les noms des langues disponibles.
```
lang="fr"
langs="fr,en"
langnames="Français,English"
```