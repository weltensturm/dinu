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
		string[] dirs;
		foreach(i, entry; dir.dirContent){
			if(!active)
				return;
			string path = entry
				.expandTilde
				.buildNormalizedPath
				.unixClean;
			try{
				if(entry.isDir){
					dirs ~= path;
					add(new CommandDir(path));
				}else{
					auto attr = getAttributes(path);
					if(attr & (1 + (1<<3)))
						add(new CommandExec(path));
					add(new CommandFile(path));
				}
				Thread.sleep(4.msecs);
			}catch(Throwable t){
				writeln(t);
			}
		}
		foreach(subdir; dirs)
			loadFiles(subdir, 1);
	}

	void postLoad(string dir, int depth){
		task({
			loadFiles(dir, depth);
		}).executeInNewThread;
	}

}

