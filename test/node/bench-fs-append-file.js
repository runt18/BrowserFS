this.tests.bench_append = function(){
    var rootFS = fs.getRootFS();
    if (rootFS.isReadOnly()) return;

    var start = Date.now();

    fs.appendFile('file.txt', "new data", function(err){
        if(err){
            throw new Error('Benchmark: append file failed.');
        }
        else {
            var end = Date.now();
            var diff = end - start;
            console.log('Append ran in ' + diff + ' ms.');
        }
    });
};
