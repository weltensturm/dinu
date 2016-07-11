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
		loadFiles(path, depth);
	}

	private void loadFiles(string dir, int depth){
		dir = dir
			.unixClean
			.expandTilde
			.absolutePath
			.chomp("/") ~ "/";
		if(dirCompleted(dir))
			return;
		foreach(i, entry; dir.dirContent){
			string path = entry
				.expandTilde
				.buildNormalizedPath
				.unixClean;
			try{
				if(entry.isDir){
					if(depth)
						loadFiles(path, depth-1);
					add(new CommandDir(path));
				}else{
					auto attr = getAttributes(path);
					if(attr & (1 + (1<<3)))
						add(new CommandExec(path));
					add(new CommandFile(path));
				}
			}catch(Throwable t){
				writeln(t);
			}
		}
	}

	void postLoad(string dir, int depth){
		task({
			loadFiles(dir, depth);
		}).executeInNewThread;
	}

}

