module dinu.content.files;


import
	std.string,
	std.path,
	std.file,
	std.stdio,
	std.parallelism,
	dinu.dinu,
	dinu.util,
	dinu.content.content,
	dinu.content.executables,
	dinu.command,
	draw;


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
		dir = dir.chompPrefix(getcwd ~ '/').chomp("/") ~ "/";
		if(dirCompleted(dir))
			return;
		foreach(i, entry; dir.expandTilde.dirContent){
			string path = buildNormalizedPath(entry).chompPrefix(getcwd ~ '/').unixClean;
			try{
				if(entry.isDir){
					if(depth){
						loadFiles(entry, depth-1);
					}
					add(new CommandDir(path.unixEscape));
				}else{
					auto attr = getAttributes(path);
					if(attr & (1 + (1<<3)))
						add(new CommandExec(path.unixEscape));
					add(new CommandFile(path.unixEscape));
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


class CommandFile: Command {

	private this(){}

	this(string name){
		this.name = name;
		type = Type.file;
		color = options.colorFile;
		parts = name.split('/');
	}

	string[] parts;

	override size_t score(){
		return 10;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		int advance = 0;
		foreach(i, part; parts){
			if(i+1 < parts.length){
				advance += dc.text([pos.x+advance, pos.y], part, options.colorDir);
				advance += dc.text([pos.x+advance, pos.y], "/", options.colorOutput);
			}else
				advance += dc.text([pos.x+advance, pos.y], part, options.colorFile);
		}
		return advance;
	}

	override void run(){
		spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
	}

}


class CommandDir: CommandFile {

	this(string name){
		type = Type.directory;
		super(name);
		parts ~= "";
	}

	override size_t score(){
		return 11;
	}

	override void run(){
		spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
	}

}
