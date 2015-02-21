module dinu.command;

import
	core.sync.mutex,
	std.string,
	std.path,
	std.process,
	std.parallelism,
	std.algorithm,
	std.array,
	std.stdio,
	std.file,
	dinu.xclient,
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


class Command {
	abstract int draw(int[2] pos);
	abstract string text();
	abstract string filterText();
	//bool lessenScore();
	abstract int score();
	abstract void run(string params);
	Type type;
}


class CommandFile: Command {

	string name;
	FontColor color;

	this(string name){
		this.name = name;
		type = Type.file;
		color = colorFile;
	}

	override string text(){
		return name;
	}

	override string filterText(){
		return name;
	}

	override int score(){
		return 0;
	}

	override int draw(int[2] pos){
		dc.text(pos, name, color);
		return pos[0]+dc.textWidth(name);
	}

	override void run(string params){
		spawnCommand(`xdg-open %s || exo-open %s`.format(name,name));
	}

}

class CommandDir: CommandFile {

	this(string name){
		super(name);
		type = Type.directory;
		color = colorDir;
	}

	override int score(){
		return 2;
	}


}

class CommandExec: CommandFile {

	this(string name){
		super(name);
		type = Type.script;
		color = colorExec;
	}

	override int score(){
		return 5;
	}

	override void run(string params){
		spawnCommand(name ~ " " ~ params);
	}

}

class CommandHistory: CommandExec {

	size_t idx;

	this(string name, size_t idx){
		super(name);
		type = Type.history;
		this.idx = idx;
	}

	override int score(){
		return idx*1000;
	}

}

class CommandOutput: CommandExec {
	
	size_t idx;
	string output;

	this(string command, string output, size_t idx, bool err){
		super(command);
		type = Type.output;
		this.output = output;
		this.idx = idx;
		color = err ? colorError : colorText;
	}

	override int score(){
		return idx*1000;
	}

	override int draw(int[2] pos){
		dc.text(pos, text, colorHint);
		pos[0] += dc.textWidth(text);
		dc.text(pos, output, color);
		return pos[0];
	}

}

class CommandDesktop: CommandFile {

	string exec;
	FontColor colorHint;

	this(string name, string exec){
		super(name);
		type = Type.desktop;
		this.exec = exec;
		color = colorDesktop;
		colorHint = dinu.xclient.colorHint;
	}

	override int draw(int[2] pos){
		int r = super.draw(pos);
		dc.text([r+5, pos[1]], exec, colorHint);
		return pos[0];
	}


	override int score(){
		return 100;
	}

	override string filterText(){
		return exec ~ name;
	}

	override void run(string params){
		spawnCommand(exec.replace("%f", params).replace("%F", params).replace("%u", params).replace("%U", params));
	}

}


void spawnCommand(string command){
	auto dg = {
		try{
			command = command.strip;
			auto userdir = options.configPath.expandTilde;
			writeln("Running \"%s\"".format(command));
			auto history = userdir ~ ".history";
			if(history.exists)
				history.append(command ~ '\n');
			else
				std.file.write(history, command ~ '\n');
			auto mutex = new Mutex;
			auto pipes = pipeShell(command);
			task({
				foreach(line; pipes.stdout.byLine)
					log("[%s] %s".format(command, line));
			}).executeInNewThread;
			foreach(line; pipes.stderr.byLine)
				log("ERR [%s] %s".format(command, line));
			pipes.pid.wait;
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
		writeln(text);
	}
}

