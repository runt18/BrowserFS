var randomString = function(length){
    var chars = [];
    for(var i = 0; i < length; i++){
        chars.push(String.fromCharCode(Math.floor(Math.random() * 100)));
    }
    return chars.join('');
};

this.benchmarks.bench_append = function(){
    var rootFS = fs.getRootFS();
    if (rootFS.isReadOnly()) return;

    var numStrings = 100;
    var length = 100;
    var strings = [];

    for(var i = 0; i < numStrings; i++){
        strings.push(randomString(length));
    }

    var start = Date.now();

    var fail = function(){
        throw new Error('Benchmark: append file failed.');
    };

    var append = function(data, cb){
        fs.appendFile('append-bench.txt', data, function(err){
            if(err){
                fail();
                cb(err);
            }
            else {
                cb(null);
            }
        });
    };

    var finished = function(err){
        if(err){
            fail();
        }
        else {
            var end = Date.now();
            var diff = end - start;
            console.log(rootFS.getName() + ' backend appended ' + numStrings + ' strings in ' + diff + ' ms.');
        }
    };

    async.each(strings, append, finished);
};
