module dinu.command;

import
	core.sync.mutex,
	std.conv,
	std.array,
	std.string,
	std.path,
	std.process,
	std.parallelism,
	std.algorithm,
	std.array,
	std.stdio,
	std.datetime,
	std.file,
	std.math,
	std.regex,
	dinu.util,
	dinu.xclient,
	dinu.dinu,
	dinu.commandBuilder,
	dinu.draw;


__gshared:


enum Type {

	none,
	script,
	desktop,
	history,
	file,
	directory,
	output,
	special,
	bashCompletion,
	processInfo

}


class Command {

	string name;
	Type type;
	string color;
	string parameter;

	protected this(){}

	this(string name){
		this.name = name;
		type = Type.file;
		color = options.colorFile;
	}

	string serialize(){
		return name;
	}

	string text(){
		return name;
	}

	string filterText(){
		return name;
	}

	string hint(){
		return "";
	}

	size_t score(){
		return 0;
	}

	abstract void run();

	int draw(DrawingContext dc, int[2] pos, bool selected){
		int origX = pos.x;
		pos.x += dc.text(pos, text, color);
		pos.x += dc.text(pos, ' ' ~ parameter, options.colorInput);
		return pos.x-origX;
	}

	void spawnCommand(string command, string arguments=""){
		execute(type, serialize.replace("!", "\\!"), command, arguments.replace("!", "\\!"));
	}

}



void execute(Type type, string serialized, string command, string parameter=""){
	auto dg = {
		try{
			string command = (command.strip ~ ' ' ~ parameter).strip;
			if(!serialized.length)
				serialized = command;
			"running: \"%s\" in %s".format(command, options.configPath).writeln;
			auto pipes = pipeShell(command);
			auto pid = pipes.pid.processID;
			formatExec(pid, type, serialized, parameter).logExec;
			auto reader = task({
				foreach(line; pipes.stdout.byLine){
					if(line.length)
						"%s stdout %s".format(pid, line).log;
				}
			});
			reader.executeInNewThread;
			foreach(line; pipes.stderr.byLine){
				if(line.length)
					"%s stderr %s".format(pid, line).log;
			}
			reader.yieldForce;
			auto res = pipes.pid.wait;
			"%s exit %s".format(pid, res).log;
		}catch(Throwable t)
			writeln(t);
	};
	task(dg).executeInNewThread;
}

void openFile(string path){
	openPath(path, Type.file);
}

void openDir(string path){
	openPath(path, Type.directory);
}

void openPath(string path, Type type){
	auto command = `exo-open "%s" || xdg-open "%s"`.format(path,path);
	execute(type, path, command);
}