module dinu.command.talkProcess;


import dinu;


__gshared:


class CommandTalkProcess: Command {

	string command;
	size_t pid;

	this(size_t pid, string command){
		super("@%s".format(pid));
		this.pid = pid;
		this.command = command;
		type = Type.processInfo;
	}

	override size_t score(){
		return to!int(pid)+1000;
	}

	override string filterText(){
		return name ~ ' ' ~ command;
	}

	override string hint(){
		return command;
	}

	override void run(){
		std.file.write("/proc/%s/fd/0".format(pid), (parameter ~ '\n'));
	}

}
