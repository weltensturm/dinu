module dinu.loader.files;


import dinu;


__gshared:


class FilesLoader: ChoiceLoader {

	string path;
	int depth;
	bool delegate(string) dirCompleted;

	this(string path, int depth, bool delegate(string) dirCompleted){
		this.path = path;
		this.depth = depth;
		this.dirCompleted = dirCompleted;
		super();
	}

	override void run(){
		loadDir(path);
	}

	private void loadDir(string path){
		auto dirs = [path];
		for(int i=0; i<dirs.length; i++){
			if(!active)
				return;
			dirs ~= loadFiles(dirs[i], 1);
		}
	}

	private string[] loadFiles(string dir, int depth){
		dir = dir
			.unixClean
			.expandTilde
			.absolutePath
			.chomp("/") ~ "/";
		if(dirCompleted(dir))
			return [];
		string[] dirs;
		foreach(i, entry; dir.dirContent){
			if(!active)
				return [];
			string path = entry
				.expandTilde
				.buildNormalizedPath
				.unixClean;
			if(path.isSymlink)
				continue;
			try{
				if(entry.isDir){
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

	void postLoad(string path, int depth){
		task({
			loadDir(path);
		}).executeInNewThread;
	}

}

