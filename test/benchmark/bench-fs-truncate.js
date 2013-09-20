var sum = function(arr){
  var n = 0;
  for(var i = 0, l = arr.length; i < l; i++){
    n += arr[i];
  }
  return n;
};

var mean = function(arr){
  return sum(arr) / arr.length;
};

this.benchmarks.bench_truncate = function(){
  var rootFS = fs.getRootFS();
  if (rootFS.isReadOnly()) return;

  var times = [];
  var trials = 10;
  var lengths = [];
  var iterations = 100;
  var i = iterations;
  while(--i > 0){
    lengths.push(i);
  }

  var startData = new Array(100).join('a');

  var finished = function(err){
    if(err){
      fail(err);
    }
    else {
      var end = Date.now();
      var diff = end - start;
      times.push(diff);
      if(times.length === trials){
        console.log(rootFS.getName() + ' backend truncated a file ' + iterations + ' times in ' + mean(times) + ' ms.');
      }
    }
  };

  var fail = function(err){
    throw new Error('Benchmark: truncate file failed: ' + err);
  };

  var i = 0;
  var start;

  var runLoop = function(){
    var path = 'truncate' + i + '.txt';
    fs.writeFile(path, startData, function(err){
      if (err) {
        fail(err);
      }
      else {
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

        start = Date.now();
        async.eachSeries(lengths, truncate, finished);
        i++;
        if(i < trials){
          runLoop();
        }
      }
    });
  }
};
