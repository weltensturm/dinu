module dinu.command.dir;


import dinu;


__gshared:


shared immutable class CommandDir: CommandFile {

	this(string name){
		super(Type.directory, name, true);
	}

	override string text(){
		return parts.join("/").chomp("/");
	}

	override size_t score(){
		return 11;
	}

	override void run(string){
		options.configPath.openDir(name);
	}

}
