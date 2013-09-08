var load = function(){
  console.log('onload triggered');
  window.setTimeout(function(){
      var req = new XMLHttpRequest();
      req.open('GET', '/test/google/token.json');
      var data = null
      req.onerror = function(e){ console.error(req.statusText); };
      req.onload = function(e){
        if(!(req.readyState === 4 && req.status === 200)){
         console.error(req.statusText);
        }
        var creds = JSON.parse(req.response);
        window.gdfs = new BrowserFS.FileSystem.GDrive(creds);
        backends.push(gdfs);

        gdfs.empty(function(){
          generateAllTests();
        });
      };
      req.send();
    }, 1);
};
