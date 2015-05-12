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
	draw;


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
		auto dg = {
			try{
				command = (command.strip ~ ' ' ~ arguments).strip;
				writeln("running: \"%s\"".format(command));
				auto userdir = options.configPath.expandTilde;
				auto pipes = pipeShell(command);
				auto pid = pipes.pid.processID;
				log("%s exec %s!%s!%s".format(pid, type, serialize.replace("!", "\\!"), arguments.replace("!", "\\!")));
				auto reader = task({
					foreach(line; pipes.stdout.byLine){
						if(line.length)
							log("%s stdout %s".format(pid, line));
					}
				});
				reader.executeInNewThread;
				foreach(line; pipes.stderr.byLine){
					if(line.length)
						log("%s stderr %s".format(pid, line));
				}
				reader.yieldForce;
				auto res = pipes.pid.wait;
				log("%s exit %s".format(pid, res));
			}catch(Throwable t)
				writeln(t);
		};
		task(dg).executeInNewThread;
	}

}

