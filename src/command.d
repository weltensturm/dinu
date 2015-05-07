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
	dinu.xclient,
	dinu.dinu,
	dinu.content,
	dinu.launcher,
	draw;


__gshared:


enum Type {

	none =      		   0,
	script =    		1<<0,
	desktop =   		1<<1,
	history =   		1<<2,
	file =      		1<<3,
	directory = 		1<<4,
	output =    		1<<5,
	special =   		1<<6,
	bashCompletion =	1<<7

}


string[] bangSplit(string text){
	return text.split(regex(`(?<!\\)\!`)).map!`a.replace("\\!", "!")`.array;
}

string bangJoin(string[] parts){
	return parts.map!`a.replace("!", "\\!")`.join("!");
}


class Command {

	string name;
	Type type;
	string color;

	private this(){}

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

	size_t score(){
		return 0;
	}

	string parameter(){
		return "";
	}

	abstract void run(string params);

	int draw(DrawingContext dc, int[2] pos, bool selected){
		return pos.x + dc.text(pos, text, color);
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
		return pos.x+advance;
	}

	override void run(string params){
		this.spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
	}

}

class CommandBashCompletion: CommandFile {

	this(string name){
		super(name);
		type = Type.bashCompletion;
	}

}

class CommandDir: CommandFile {

	this(string name){
		type = Type.directory;
		super(name);
		parts ~= "";
	}

	override size_t score(){
		return 11;
	}

	override void run(string params){
		this.spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
	}

}

class CommandExec: Command {

	this(string name){
		this.name = name;
		type = Type.script;
		color = options.colorExec;
	}

	override size_t score(){
		return 5;
	}

	override void run(string params){
		this.spawnCommand(name, params);
	}

}

class CommandSpecial: CommandExec {

	this(string name){
		super(name);
		this.name = name;
		type = Type.special;
		color = options.colorExec;

	}

	override void run(string params){
		final switch(name){
			case "cd":
				chdir(params.expandTilde.unixClean);
				std.file.write(options.configPath, getcwd);
				log("%s exec %s!%s!%s".format(0, Type.special, serialize.replace("!", "\\!"), params.replace("!", "\\!")));
				break;
			case "clear":
				launcher.clearOutput;
				break;
			case ".":
				this.spawnCommand("xdg-open .", "");
				break;
		}
	}

}

class CommandDesktop: Command {

	string exec;

	this(string args){
		auto split = args.bangSplit;
		name = split[0];
		exec = split[1];
		color = options.colorDesktop;
		type = Type.desktop;
	}

	override string serialize(){
		return [name, exec].bangJoin;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		int r = super.draw(dc,  pos, selected);
		dc.text([r+5, pos[1]], exec, options.colorHint);
		return pos[0];
	}

	override size_t score(){
		return 7;
	}

	override string filterText(){
		return name ~ exec;
	}

	override void run(string params){
		this.spawnCommand(exec.replace("%f", params).replace("%F", params).replace("%u", params).replace("%U", params));
	}

}

class CommandHistory: Command {

	size_t idx;
	long result = long.max;
	string params;
	Type originalType;
	Command command;

	this(size_t idx, int pid, Type originalType, string serialized, string params){
		this.idx = idx;
		this.params = params;
		type = Type.history;
		switch(originalType){
			case Type.script:
				command = new CommandExec(serialized);
				break;
			case Type.desktop:
				command = new CommandDesktop(serialized);
				break;
			case Type.file:
				command = new CommandFile(serialized);
				break;
			case Type.directory:
				command = new CommandDir(serialized);
				break;
			case Type.special:
				command = new CommandSpecial(serialized);
				break;
			default:
				break;
		}
		this.name = command.text;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		string hint;
		if(result != long.max){
			if(result)
				hint = to!string(result);
			else
				hint = "";
		}else
			hint = "•";
		dc.text(pos, hint, options.colorHint, 1.45);
		pos.x = command.draw(dc, pos, selected);
		return dc.text(pos, ' ' ~ params, options.colorOutput);
	}

	override string parameter(){
		return params;
	}

	override void run(string params){
		command.run(this.params ~ " " ~ params);
	}

}

class CommandOutput: Command {
	
	size_t idx;
	string command;
	int pid;

	this(int pid, string output, size_t idx, bool err){
		super(output);
		type = Type.output;
		this.pid = pid;
		this.idx = idx;
		if(err)
			color = options.colorError;
		else
			color = options.colorOutput;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		if(!command.length && pid in running)
			command = running[pid].text;
		dc.text(pos, command, options.colorHint, 1.45);
		return super.draw(dc, pos, selected);
	}

	override void run(string params){
		auto command = new CommandExec("echo");
		if(!params.length)
			params = "xsel -ib";
		command.run("'%s' | %s".format(
			text.strip.replace("'", "'\\''"),
			params
		));
	}

}

void spawnCommand(Command caller, string command, string arguments=""){
	auto dg = {
		try{
			command = (command.strip ~ ' ' ~ arguments).strip;
			writeln("running: \"%s\"".format(command));
			auto userdir = options.configPath.expandTilde;
			auto pipes = pipeShell(command);
			auto pid = pipes.pid.processID;
			log("%s exec %s!%s!%s".format(pid, caller.type, caller.serialize.replace("!", "\\!"), arguments.replace("!", "\\!")));
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


Mutex logMutex;

shared static this(){
	logMutex = new Mutex;
}

void log(string text){
	synchronized(logMutex){
		auto path = options.configPath ~ ".log";
		if(path.exists)
			path.append(text ~ '\n');
		else
			std.file.write(path, text ~ '\n');
	}
}

