this.benchmarks.bench_truncate = function(){
  var rootFS = fs.getRootFS();
  if (rootFS.isReadOnly()) return;

  var path = 'truncate.txt';
  var startData = new Array(100).join('a');

  var fail = function(err){
    throw new Error('Benchmark: truncate file failed: ' + err);
  };

  fs.writeFile(path, startData, function(err){
    if (err) {
      fail(err);
    }
    else {
      var lengths = [];
      var iterations = 100;
      var i = iterations;
      while(--i > 0){
        lengths.push(iterations);
      }

      var truncate = function(length, cb){
        fs.truncate(path, length, function(err){
          if(err){
            fail(err);
            cb(err);
          }
          else {
            cb(null);
          }
        });
      };

      var finished = function(err){
        if(err){
          fail(err);
        }
        else {
          var end = Date.now();
          var diff = end - start;
          console.log(rootFS.getName() + ' backend truncated a file ' + iterations + ' times in ' + diff + ' ms.');
        }
      };

      var start = Date.now();
      async.eachSeries(lengths, truncate, finished);
    }
  });
};
