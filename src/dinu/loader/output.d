module dinu.loader.output;


import dinu;


shared class CommandResult {
	long result;
	size_t occurrences;
	this(){
		result = long.max;
	}
}


shared CommandResult[int] running;


class OutputLoader: ChoiceLoader {

	int[string] loaded;

	override void run(){
		auto log = options.configPath ~ ".log";
		while(!log.exists && active && runProgram)
			core.thread.Thread.sleep(10.msecs);
		loaded = loaded.init;
		auto file = new BufferedFile(log);
		file.seekEnd(0);
		size_t idx = 10000;
		task(&loadBackwards, idx-1000).executeInNewThread;
		task(&loadBackwardsExec, idx-1000).executeInNewThread;
		while(active && runProgram){
			if(!file.eof){
				auto line = cast(string)file.readLine;
				if(!line.length)
					continue;
				matchLine(line, idx++);
				matchLineExec(line, true);
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
			if(idx==0 || !active)
				break;
		}
		scope(exit)
			p.pid.kill;
	}

	void loadBackwardsExec(size_t idx){
		auto p = pipeProcess(["tac", options.configPath ~ ".exec"], Redirect.stdout);
		foreach(line; p.stdout.byLine){
			matchLineExec(to!string(line), false);
			if(idx<10000-2000)
				core.thread.Thread.sleep(4.msecs);
			if(idx==0 || !active)
				break;
		}
		scope(exit)
			p.pid.kill;
	}

	void matchLine(string line, size_t idx){
		try{
			foreach(match; line.matchAll(`([0-9]+) (\S+)(?: (.*))?`)){
				auto pid = to!int(match.captures[1]);
				if((match.captures[2] == "stdout" || match.captures[2] == "stderr") && match.captures[3].length){
					add(new immutable CommandOutput(pid, match.captures[3], idx, match.captures[2]=="stderr"));
				}
			}
		}catch(Exception e){
			writeln(e);
		}
	}

	void matchLineExec(string line, bool forward){
		try{
			foreach(match; line.matchAll(`([0-9]+) (\S+)(?: (.*))?`)){
				auto pid = to!int(match.captures[1]);
				if(match.captures[2] == "exec"){
					auto cmd = match.captures[3].bangSplit;
					/+
					if(!cmd[2].length)
						continue;
					+/
					if(pid !in running)
						running[pid] = new shared CommandResult;
					if(!exists("/proc/%s".format(pid)) && running[pid].result == long.max)
						running[pid].result = 0;
					if(cmd[1] ~ cmd[2] in loaded){
						auto l = loaded[cmd[1].idup ~ cmd[2].idup];
						running[l].occurrences++;
						continue;
					}
					auto history = new immutable CommandHistory(pid, to!Type(cmd[0]), cmd[1].dup, cmd[2].dup);
					loaded[cmd[1].idup ~ cmd[2].idup] = pid;
					running[pid].occurrences = 0;
					add(history);
				}else if(match.captures[2] == "exit"){
					if(pid !in running)
						running[pid] = new shared CommandResult;
					running[pid].result = to!int(match.captures[3]);
				}
			}
		}catch(Exception e){
			writeln(e);
		}
	}
}
