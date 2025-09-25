var path = require('path');
var fs = require('fs');

const compile = async () => {
    var gettextParser = await import("gettext-parser");
    const dir = '../www/lang';
    console.log('Compiling languages files in', path.resolve(dir));
    for(var f of fs.readdirSync(dir)) {
        if(!f.endsWith('.po')) continue;
        console.log('\tCompiling', f);
        var input = fs.readFileSync(path.join(dir, f));
        var po = gettextParser.po.parse(input);
        var mo = gettextParser.mo.compile(po);
        fs.writeFileSync(path.join(dir, path.basename(f,'.po')+'.mo'), mo);
        console.log('\tCompiled', path.basename(f,'.po')+'.mo');
    }
};


const diff = async (file1, file2, verbose) => {
    var gettextParser = await import("gettext-parser");

    console.log(`running diff on ${file1} ${file2}`);
    
    var po1 = gettextParser.po.parse(fs.readFileSync(file1));
    var po2 = gettextParser.po.parse(fs.readFileSync(file2));
    var tr1 = Object.values(po1.translations)[0];
    var tr2 = Object.values(po2.translations)[0];
    console.log(`OLD: ${Object.keys(tr1).length} entries`);
    console.log(`NEW: ${Object.keys(tr2).length} entries`);

    for(const k in tr1) {
        if(!tr2[k]) {
            var ref = tr1[k].comments?.reference;
            var maybe2 = ref && Object.values(tr2).find(t2 => t2.comments?.reference == ref)
            // console.log(ref);
            if(maybe2)
                console.log(`\x1b[46m\x1b[30m<>\x1b[0m\t< ${k}\t${tr1[k].msgstr[0]}\n\t >${maybe2.msgid}\t${maybe2.msgstr[0]}`)
            else
                console.log(`\x1b[41m\x1b[30m--\x1b[0m\t${k}`)
        }
        else if(tr2[k].msgstr[0] != tr1[k].msgstr[0])
            console.log(`\x1b[43m\x1b[30m!=\x1b[0m\t${k}\n\t<\t${tr1[k].msgstr[0]}\n\t>\t${tr2[k].msgstr[0]}`)
        else if(verbose)
            console.log(`\x1b[43m\x1b[100m==\x1b[0m\t${k}`)
    }
    for(const k in tr2) {
        if(!tr1[k]){
            // console.log(tr2[k].comments?.reference);
            console.log(`\x1b[42m\x1b[30m++\x1b[0m\t${k}`);
        }
    }
};


const update = async (potFile, poFile) => {
    var gettextParser = await import("gettext-parser");
    const readline = require('node:readline/promises');
    const input = readline.createInterface({
            input: process.stdin,
            output: process.stdout,
        });

    console.log(`running translation of ${potFile} into ${poFile}`);
    
    var pot = gettextParser.po.parse(fs.readFileSync(potFile));
    var po = gettextParser.po.parse(fs.readFileSync(poFile));
    var lang = Object.keys(po.translations)[0];
    
    for(const k in pot.translations['']) {
        if(!po.translations[lang][k]) {
            console.log(`\x1b[42m\x1b[30m++\x1b[0m\t${k}`);
            const msgstr = await input.question(`[${lang}]> `);
            po.translations[lang][k] = {
                msgid: k,
                msgstr: [msgstr]
            }
        }
        // console.log(`${k} > ${po.translations[lang][k].msgstr[0]}`)
    }
    for(const k in po.translations[lang]) {
        if(!pot.translations[''][k]){
            delete po.translations[lang][k];
        }
    }
    input.close();

    fs.writeFileSync(poFile, gettextParser.po.compile(po));
    fs.writeFileSync(poFile.slice(0,-3)+'.mo', gettextParser.mo.compile(po));
};

var argv = Array.from(process.argv);
while(!argv[0].endsWith('i18n.js')) argv.shift();

if(argv[1] == "compile")
    compile();
else if(argv[1] == "diff"){
    let v = argv.includes("-v")
    if(v) argv.splice(argv.indexOf('-v'), 1);
    diff(argv[2], argv[3], v);
}
else if(argv[1] == "update")
    update(argv[2], argv[3]);
else
    console.log(`usage:
node i18n.js compile
node i18n.js diff old.po new.po
node i18n.js update ref.pot lang.po
`)