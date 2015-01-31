module dinu.command;

import
	std.string,
	std.process,
	std.parallelism,
	std.stdio,
	dinu.xclient,
	draw;


__gshared:



interface Part {
	int draw(int[2] pos);
	string text();
	string filterText();
	//bool lessenScore();
	int score();
}

interface Command: Part {
	void run(string params);
}


class CommandFile: Command {

	string name;
	FontColor color;

	this(string name){
		this.name = name;
		color = colorFile;
	}

	override string text(){
		return name;
	}

	override string filterText(){
		return name;
	}

	override int score(){
		return 10;
	}

	override int draw(int[2] pos){
		dc.text(pos, name, color);
		return pos[0]+dc.textWidth(name);
	}

	override void run(string params){
		spawnCommand(`xdg-open %s`.format(name));
	}

}

class CommandDir: CommandFile {

	this(string name){
		super(name);
		color = colorDir;
	}

	override int score(){
		return 20;
	}


}

class CommandExec: CommandFile {

	this(string name){
		super(name);
		color = colorExec;
	}

	override int score(){
		return 1;
	}

	override void run(string params){
		spawnCommand(name ~ params);
	}

}

class CommandUserExec: CommandFile {

	this(string name){
		super(name);
		color = colorUserExec;
	}

	override int score(){
		return 1;
	}

	override void run(string params){
		spawnCommand("~/.bin/" ~ name ~ params);
	}

}

class CommandDesktop: CommandFile {

	string exec;
	FontColor colorHint;

	this(string name, string exec){
		super(name);
		this.exec = exec;
		color = colorDesktop;
		colorHint = colorHint;
	}

	override int draw(int[2] pos){
		int r = super.draw(pos);
		dc.text([r+5, pos[1]], exec, colorHint);
		return pos[0];
	}


	override int score(){
		return 1;
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
			foreach(line; pipes.stdout.byLine){
				if(!options.noNotify)
					spawnShell(`notify-send "%s"`.format(line));
				writeln(line);
			}
		}).executeInNewThread;
		foreach(line; pipes.stderr.byLine){
			if(!options.noNotify)
				spawnShell(`notify-send "%s" -u critical`.format(line));
			writeln(line);
		}
		pipes.pid.wait;
	};
	task(dg).executeInNewThread;
}

