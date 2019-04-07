module dinu.loader.files;


import dinu;


__gshared:


auto normalizePath(string path){
	return path
		.unixClean
		.expandTilde
		.absolutePath;
}


class FilesLoader: ChoiceLoader {

	string path;
	int depth;
	string[] loadedDirs;

	this(string path, int depth){
		if(depth == -1)
			depth = 9999;
		this.path = path;
		this.depth = depth;
		super();
	}

	override void run(){
		loadDir(path, depth);
	}

	private void loadDir(string path, size_t depth=0){
		auto dirs = loadFiles(path);
		if(depth > 0){
			foreach(dir; dirs){
				loadDir(dir, depth-1);
			}
		}
	}

	private string[] loadFiles(string dir){
		dir = dir
			.normalizePath
			.chomp("/") ~ "/";
		synchronized(this){
			if(loadedDirs.canFind(dir))
				return [];
			loadedDirs ~= dir;
		}
		string[] dirs;
		foreach(i, entry; dir.dirContent){
			if(!active)
				return [];
			string path = entry.normalizePath;
			if(path.isSymlink)
				continue;
			try{
				if(path.isDir){
					dirs ~= path;
					add(new immutable CommandDir(path));
				}else{
					auto attr = getAttributes(path);
					if(attr & (1 + (1<<3)))
						add(new immutable CommandExec(path));
					add(new immutable CommandFile(path));
				}
				Thread.sleep(1.msecs);
			}catch(Throwable t){
				writeln(t);
			}
		}
		return dirs;
	}

	void update(dstring filterText){
		auto path = filterText.to!string.normalizePath;
		if(path.chompAll("/").length != path.length-1)
			return;
		if(path.exists && path.isDir){
			task({
				loadDir(path);
			}).executeInNewThread;
		}
	}

}

auto chompAll(string text, string delim){
	while(text.endsWith(delim))
		text = text.chomp(delim);
	return text;
}