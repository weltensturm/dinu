module dinu.command.dir;


import dinu;


__gshared:


shared immutable class CommandDir: CommandFile {

	this(string name){
		super(Type.directory, name, true);
	}

	override string filterText(){
		return super.filterText ~ "/";
	}

	override size_t score(){
		return 11;
	}

	override void run(string){
		options.configPath.openDir(name);
	}

}
