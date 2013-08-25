if(BrowserFS.FileSystem.Dropbox.isAvailable()){
    dbfs = new BrowserFS.FileSystem.Dropbox(true);
    backends.push(dbfs);
    dbfs.empty(function(){
    });
    generateAllTests();

}
