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
			if((getAttributes(d) & S_IRUSR) && d.isDir && (d ~ "/comm").exists && d.chompPrefix("/proc/").isNumeric){
				add(new CommandTalkProcess(d.chompPrefix("/proc/").to!size_t, (d ~ "/comm").read.to!string.strip));
			}
		}
	}

}


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
		"/proc/%s/fd/0".format(pid).write(parameter ~ '\n');
	}

}
