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
	draw;


__gshared:


enum Type {

	none =         0,
	script =    1<<0,
	desktop =   1<<1,
	history =   1<<2,
	file =      1<<3,
	directory = 1<<4,
	output =    1<<5

}


string[] bangSplit(string text){
	return text.split(regex(`(?<!\\)\!`)).map!`a.replace("\\!", "!")`.array;
}

string bangJoin(string[] parts){
	return parts.map!`a.replace("!", "\\!")`.join("!");
}


class Command {
	abstract int draw(int[2] pos, bool selected);
	abstract string text();
	abstract string filterText();
	abstract string serialize();
	//bool lessenScore();
	abstract size_t score();
	abstract void run(string params);
	Type type;
}


class CommandFile: Command {

	string name;
	FontColor color;

	private this(){}

	this(string name){
		this.name = name;
		type = Type.file;
		color = colorFile;
	}

	override string serialize(){
		return name;
	}

	override string text(){
		return name;
	}

	override string filterText(){
		return name;
	}

	override size_t score(){
		return 0;
	}

	override int draw(int[2] pos, bool selected){
		dc.clip([pos.x, pos.y-dc.font.height+1], [client.size.w-pos.x, barHeight]);
		int x = 0;
		if(selected && dc.textWidth(text) > client.size.w-pos.x){
			int diff = dc.textWidth(text) - (client.size.w-pos.x);
			x = cast(int)(diff*(min(1.0, max(-1.0, sin(client.dt/sqrt(diff*6283.1))))+1)/2);
		}
		int advance = dc.text([pos.x-x, pos.y], text, color);
		dc.noclip;
		return pos.x+advance;
	}

	override void run(string params){
		this.spawnCommand(`exo-open %s || xdg-open %s`.format(name,name));
	}

}

class CommandDir: CommandFile {

	this(string name){
		this.name = name;
		type = Type.directory;
		color = colorDir;
	}

	override size_t score(){
		return 2;
	}


}

class CommandExec: CommandFile {

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

class CommandHistory: CommandFile {

	size_t idx;
	long result = long.max;
	string params;
	Type originalType;
	Command command;

	this(size_t idx, int pid, Type originalType, string serialized, string params){
		this.idx = idx;
		this.params = params;
		this.name = serialized;
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
			default:
				break;
		}
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(int[2] pos, bool selected){
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
		pos.x = command.draw(pos, selected);
		return dc.text(pos, ' ' ~ params, colorOutput);
	}

	override void run(string params){
		command.run(this.params ~ " " ~ params);
	}

}

class CommandOutput: CommandFile {
	
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

	override int draw(int[2] pos, bool selected){
		if(!selected)
			dc.rect([pos.x-4, pos.y-dc.font.height+1], [client.size.w-pos.x+4, barHeight], colorOutputBg);
		if(command.length){
			dc.text(pos, command, colorHint, 1.45);
		}else if(pid in running){
			command = running[pid].text;
		}
		return super.draw(pos, selected);
	}

	override void run(string params){
		auto command = new CommandExec("echo");
		command.run("'%s' | xsel -ib".format(
			text.strip.replace("'", "'\\''")
		));
	}

}

class CommandDesktop: CommandFile {

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

	override int draw(int[2] pos, bool selected){
		int r = super.draw(pos, selected);
		dc.text([r+5, pos[1]], exec, colorHint);
		return pos[0];
	}

	override size_t score(){
		return 100;
	}

	override string filterText(){
		return exec ~ name;
	}

	override void run(string params){
		this.spawnCommand(exec.replace("%f", params).replace("%F", params).replace("%u", params).replace("%U", params));
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

