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

	none =         0,
	script =    1<<0,
	desktop =   1<<1,
	history =   1<<2,
	file =      1<<3,
	directory = 1<<4,
	output =    1<<5,
	special =   1<<6

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

	private this(){}

	this(string name){
		this.name = name;
		type = Type.file;
		color = colorFile;
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

	//bool lessenScore();
	abstract void run(string params);

	int draw(DrawingContext dc, int[2] pos, bool selected){
		dc.clip([pos.x, pos.y-dc.font.height+1], [client.size.w-pos.x, barHeight]);
		int x = 0;
		if(selected && dc.textWidth(text) > client.size.w-pos.x){
			int diff = dc.textWidth(text) - (client.size.w-pos.x);
			x = cast(int)(-20 + (diff + 40)*(min(1.0, max(-1.0, sin(client.dt/sqrt(diff*6283.1))))+1)/2);
		}
		int advance = dc.text([pos.x-x, pos.y], text, color);
		dc.noclip;
		return pos.x+advance;
	}

	FontColor color;
}


class CommandFile: Command {

	private this(){}

	this(string name){
		this.name = name;
		type = Type.file;
		color = colorFile;
		parts = name.split('/');
	}

	string[] parts;

	override size_t score(){
		return 10;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		dc.clip([pos.x, pos.y-dc.font.height+1], [client.size.w-pos.x, barHeight]);
		int x = 0;
		if(selected && dc.textWidth(text) > client.size.w-pos.x){
			int diff = dc.textWidth(text) - (client.size.w-pos.x);
			x = cast(int)(-20 + (diff + 40)*(min(1.0, max(-1.0, sin(client.dt/sqrt(diff*6283.1))))+1)/2);
		}
		int advance = 0;
		foreach(i, part; parts){
			if(i+1 < parts.length){
				advance += dc.text([pos.x-x+advance, pos.y], part, colorDir);
				advance += dc.text([pos.x-x+advance, pos.y], "/", colorOutput);
			}else
				advance += dc.text([pos.x-x+advance, pos.y], part, colorFile);
		}
		dc.noclip;
		return pos.x+advance;
	}

	override void run(string params){
		this.spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
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
		color = colorExec;
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
		color = colorExec;

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
		color = colorDesktop;
		type = Type.desktop;
	}

	override string serialize(){
		return [name, exec].bangJoin;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		int r = super.draw(dc,  pos, selected);
		dc.text([r+5, pos[1]], exec, colorHint);
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
		//if(!selected)
		//	dc.rect([pos.x-4, pos.y-dc.font.height+1], [client.size.w-pos.x+4, barHeight], colorInputBg);
		string hint;
		if(result != long.max){
			if(result)
				hint = to!string(result);
			else
				hint = "";
		}else
			hint = "•";
		dc.text(pos, hint, colorHint, 1.45);
		pos.x = command.draw(dc, pos, selected);
		return dc.text(pos, ' ' ~ params, colorOutput);
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
		super(output.dup); // fucking garbage collector doesn't know its place
		type = Type.output;
		this.pid = pid;
		this.idx = idx;
		if(err)
			color = colorError;
		else
			color = colorOutput;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		//if(!selected)
		//	dc.rect([pos.x-4, pos.y-dc.font.height+1], [client.size.w-pos.x+4, barHeight], colorOutputBg);
		if(!command.length && pid in running)
			command = running[pid].text;
		dc.text(pos, command, colorHint, 1.45);
		return super.draw(dc, pos, selected);
	}

	override void run(string params){
		auto command = new CommandExec("echo");
		command.run("'%s' | xsel -ib".format(
			text.strip.replace("'", "'\\''")
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

