module dinu.command.dir;


import dinu;


__gshared:


class CommandDir: CommandFile {

	this(string name){
		type = Type.directory;
		super(name);
		parts ~= "";
	}

	override string filterText(){
		return super.filterText ~ "/";
	}

	override size_t score(){
		return 11;
	}

	override void run(){
		options.configPath.openDir(name);
	}

}
