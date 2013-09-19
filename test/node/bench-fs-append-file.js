var randomString = function(length){
    var chars = [];
    for(var i = 0; i < length; i++){
        chars.push(String.fromCharCode(Math.floor(Math.random() * 100)));
    }
    return chars.join('');
};

this.tests.bench_append = function(){
    var rootFS = fs.getRootFS();
    if (rootFS.isReadOnly()) return;

    var numStrings = 100;
    var length = 100;
    var strings = [];

    for(var i = 0; i < numStrings; i++){
        strings.push(randomString(length));
    }

    var start = Date.now();

    var append = function(data, cb){
        fs.appendFile('append-bench.txt', data, function(err){
            if(err){
                throw new Error('Benchmark: append file failed.');
                cb(err);
            }
            else {
                cb(null);
            }
        });
    };

    var finished = function(err){
        var end = Date.now();
        var diff = end - start;
        console.log('Appended ' + numStrings + ' strings in ' + diff + ' ms.');
    };

    async.each(strings, append, finished);
};
