#!/bin/sh

for dir in ../www/theme/*/; do
    echo "build "$dir"css/style.min.css"
    cat $dir/css/variables.less | grep -v keyframes | sed s/@/$/g > $dir/css/style.scss
    cat $dir/css/bootswatch.scss >> $dir/css/style.scss
    sass $dir/css/style.scss $dir/css/style.css
    sass --style=compressed $dir/css/style.scss $dir/css/style.min.css
done