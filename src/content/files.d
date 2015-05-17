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
		dir = dir.expandTilde.chompPrefix(getcwd ~ '/').chomp("/") ~ "/";
		if(dirCompleted(dir))
			return;
		foreach(i, entry; dir.dirContent){
			string path = buildNormalizedPath(entry).chompPrefix(getcwd ~ '/').unixClean;
			try{
				if(entry.expandTilde.isDir){
					if(depth)
						loadFiles(entry.expandTilde, depth-1);
					addEntry(path, Type.directory);
				}else{
					auto attr = getAttributes(path);
					if(attr & (1 + (1<<3)))
						addEntry(path, Type.script);
					addEntry(path, Type.file);
				}
			}catch(Throwable t){
				writeln(t);
			}
		}
	}

	void addEntry(string path, Type type){
		string[] paths = [path];
		if(path.chompPrefix("~".expandTilde) != path){
			paths ~= "~" ~ path.chompPrefix("~".expandTilde);
		}
		foreach(p; paths){
			switch(type){
				case Type.directory:
					add(new CommandDir(p));
					break;
				case Type.script:
					add(new CommandExec(p));
					break;
				case Type.file:
					add(new CommandFile(p));
					break;
				default:
					break;
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

	override string filterText(){
		return super.filterText ~ '/';
	}

	override size_t score(){
		return 11;
	}

	override void run(){
		spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
	}

}
