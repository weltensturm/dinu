module dinu.command;

import
	std.string,
	std.process,
	std.parallelism,
	dinu.xclient,
	draw;


interface Part {
	int draw(int[2] pos);
	string text();
	string filterText();
	bool lessenScore();
}

interface Command: Part {
	void run(string params);
}


class CommandFile: Command {

	string name;
	FontColor color;

	this(string name){
		this.name = name;
		color = dc.fontColor(options.colorFile);
	}

	override string text(){
		return name;
	}

	override string filterText(){
		return name;
	}

	override bool lessenScore(){
		return false;
	}

	override int draw(int[2] pos){
		dc.text(pos, name, color);
		return pos[0];
	}

	override void run(string params){
		spawnCommand(`xdg-open "%s"`.format(name));
	}

}

class CommandDir: CommandFile {

	this(string name){
		super(name);
		color = dc.fontColor(options.colorDir);
	}

}

class CommandExec: CommandFile {

	this(string name){
		super(name);
		color = dc.fontColor(options.colorExec);
	}

	override bool lessenScore(){
		return true;
	}

	override void run(string params){
		spawnCommand(name ~ params);
	}

}

class CommandDesktop: CommandFile {

	string exec;

	this(string name, string exec){
		super(name);
		this.exec = exec;
		color = dc.fontColor(options.colorDesktop);
	}

	override bool lessenScore(){
		return true;
	}

	override string filterText(){
		return exec ~ name;
	}

	override void run(string params){
		spawnCommand(exec);
	}

}


void spawnCommand(string command){
	auto dg = {
		auto pipes = pipeShell(command);
		task({
			foreach(line; pipes.stdout.byLine)
				spawnShell(`notify-send "%s"`.format(line));
		}).executeInNewThread;
		foreach(line; pipes.stderr.byLine)
			spawnShell(`notify-send "%s" -u critical`.format(line));
		pipes.pid.wait;
	};
	task(dg).executeInNewThread;
}

