#!/bin/sh

for dir in ../www/theme/*/; do
    echo "updates variables.scss for imports"
    cat $dir/css/variables.less | grep -v keyframes | sed s/@/$/g > $dir/css/variables.scss
    echo "build "$dir"css/style.min.css"
    sass $dir/css/style.scss $dir/css/style.css
    sass --style=compressed $dir/css/style.scss $dir/css/style.min.css
done