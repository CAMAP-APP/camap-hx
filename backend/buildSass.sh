#!/bin/sh

for dir in ../www/theme/*/; do
    echo "build "$dir"css/style.min.css"
    sass $dir/css/bootswatch.scss $dir/css/style.css
    sass --style=compressed $dir/css/style.scss $dir/css/style.min.css
done