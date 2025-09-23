var path = require('path');
var fs = require('fs');
(async () => {
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
        console.log('\tCompiled', path.basename(f,'.po')+'.mo'));
    }
})();