if(BrowserFS.FileSystem.Dropbox.isAvailable()){
    // Pass true to enable testing mode
    dbfs = new BrowserFS.FileSystem.Dropbox(true);
    backends.push(dbfs);
    dbfs.empty(function(){
        generateAllTests();
    });
}
