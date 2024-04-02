import replace from '@rollup/plugin-replace';
import {terser} from 'rollup-plugin-terser';
import resolve from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';

export default {
    input: 'libs/libs.js', // Le point d'entrée, équivalent à votre fichier libs/libs.js
    output: {
        file: '../www/js/libs.prod.js', // Le fichier de sortie
        format: 'iife' // Le format de module, iife est souvent utilisé pour les scripts de navigateur
    },
    plugins: [
        resolve(),
        commonjs(),
        replace({
            'process.env.NODE_ENV': JSON.stringify('production'), // Remplace les variables d'environnement
            preventAssignment: true
        }),
        terser() // Minifie le code
    ]
};
