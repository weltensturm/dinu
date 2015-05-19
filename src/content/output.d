module dinu.content.output;

import
	std.file,
	std.datetime,
	std.stream,
	std.parallelism,
	std.process,
	std.conv,
	std.regex,
	std.string,
	std.stdio,
	dinu.dinu,
	dinu.util,
	dinu.xclient,
	dinu.content.content,
	dinu.content.executables,
	dinu.content.files,
	dinu.command,
	draw;


__gshared:


private {
	CommandHistory[int] running;
	int[int] results;
}


class OutputLoader: ChoiceLoader {

	override void run(){
		auto log = options.configPath ~ ".log";
		while(!log.exists && active && runProgram)
			core.thread.Thread.sleep(10.msecs);
		auto file = new BufferedFile(log);
		file.seekEnd(0);
		size_t idx = 10000;
		task(&loadBackwards, idx-1000).executeInNewThread;
		while(active && runProgram){
			if(!file.eof){
				auto line = cast(string)file.readLine;
				if(!line.length)
					continue;
				matchLine(line, idx++);
			}else
				core.thread.Thread.sleep(5.msecs);
		}
	}

	void loadBackwards(size_t idx){
		auto p = pipeProcess(["tac", options.configPath ~ ".log"], Redirect.stdout);
		foreach(line; p.stdout.byLine){
			matchLine(to!string(line), idx--);
			if(idx<10000-2000)
				core.thread.Thread.sleep(4.msecs);
			if(idx==0 || !runProgram)
				break;
		}
	}

	void matchLine(string line, size_t idx){
		try{
			foreach(match; line.matchAll(`([0-9]+) (\S+)(?: (.*))?`)){
				auto pid = to!int(match.captures[1]);
				if(match.captures[2] == "exec"){
					auto cmd = match.captures[3].bangSplit;
					auto history = new CommandHistory(idx, pid, to!Type(cmd[0]), cmd[1].dup, cmd[2].dup);
					running[pid] = history;
					if(pid in results){
						history.result = results[pid];
					}else if(!exists("/proc/%s".format(pid))){
						history.result = 0;
					}
					add(history);
				}
				if((match.captures[2] == "stdout" || match.captures[2] == "stderr") && match.captures[3].length){
					add(new CommandOutput(pid, match.captures[3], idx, match.captures[2]=="stderr"));
				}else if(match.captures[2] == "exit"){
					if(pid in running)
						running[pid].result = to!int(match.captures[3]);
					else
						results[pid] = to!int(match.captures[3]);
				}
			}
		}catch(Exception e){
			writeln(e);
		}
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
		dc.text(pos, command, options.colorHint, 1.8);
		return super.draw(dc, pos, selected);
	}

	override void run(){}

}


class CommandHistory: Command {

	size_t idx;
	long result = long.max;
	Type originalType;
	Command command;

	this(size_t idx, int pid, Type originalType, string serialized, string parameter){
		this.idx = idx;
		this.parameter = parameter;
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
				command = new CommandExec(serialized);
				break;
		}
		this.name = command.text;
	}

	override string filterText(){
		return super.filterText() ~ parameter;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		auto origX = pos.x;
		if(result != long.max){
			if(result)
				dc.rect([pos.x-0.4.em,pos.y], [0.1.em, 1.em], options.colorError);
		}else
			dc.rect([pos.x-0.4.em,pos.y], [0.1.em, 1.em], options.colorHint);
		pos.x += command.draw(dc, pos, selected);
		if(parameter.length)
			pos.x += dc.text(pos, parameter, options.colorOutput);
		return pos.x-origX;
	}

	override void run(){
		command.parameter ~= parameter;
		command.run;
	}

}
