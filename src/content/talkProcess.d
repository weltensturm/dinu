module dinu.content.talkProcess;


import
	core.sys.posix.sys.stat,
	std.file,
	std.string,
	std.conv,
	dinu.content.content,
	dinu.command;


class TalkProcessLoader: ChoiceLoader {

	override void run(){
		foreach(d; "/proc".dirContent){
			if((getAttributes(d) & S_IRUSR) && d.isDir && (d ~ "/comm").exists){
				add(new CommandTalkProcess(d.chompPrefix("/proc/"), (d ~ "/comm").read.to!string.strip));
			}
		}
	}

}


class CommandTalkProcess: Command {

	string command;
	string pid;

	this(string pid, string command){
		super("@" ~ pid);
		this.pid = pid;
		this.command = command;
		type = Type.processInfo;
	}

	override string filterText(){
		return name ~ ' ' ~ command;
	}

	override string hint(){
		return command;
	}

	override void run(){
		("/proc/" ~ pid ~ "/fd/0").append(parameter);
	}

}
