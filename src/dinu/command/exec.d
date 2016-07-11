module dinu.command.exec;


import dinu;


__gshared:


class CommandExec: Command {

	this(string name){
		this.name = name;
		type = Type.script;
		color = options.colorExec;
	}

	override size_t score(){
		return 5;
	}

	override void run(){
		spawnCommand(name, parameter);
	}

}
