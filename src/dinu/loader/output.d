module dinu.loader.output;


import dinu;


__gshared:


CommandHistory[int] running;
int[int] results;


class OutputLoader: ChoiceLoader {

	string[] loaded;

	override void run(){
		auto log = options.configPath ~ ".log";
		while(!log.exists && active && runProgram)
			core.thread.Thread.sleep(10.msecs);
		loaded = [];
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
		scope(exit)
			p.pid.kill;
	}

	void loadBackwardsExec(size_t idx){
		auto p = pipeProcess(["tac", options.configPath ~ ".exec"], Redirect.stdout);
		foreach(line; p.stdout.byLine){
			matchLineExec(to!string(line), idx--);
			if(idx<10000-2000)
				core.thread.Thread.sleep(4.msecs);
			if(idx==0 || !runProgram)
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
					add(new CommandOutput(pid, match.captures[3], idx, match.captures[2]=="stderr"));
				}
			}
		}catch(Exception e){
			writeln(e);
		}
	}

	void matchLineExec(string line, size_t idx){
		try{
			foreach(match; line.matchAll(`([0-9]+) (\S+)(?: (.*))?`)){
				auto pid = to!int(match.captures[1]);
				if(match.captures[2] == "exec"){
					auto cmd = match.captures[3].bangSplit;
					if(!cmd[2].length)
						continue;
					auto history = new CommandHistory(idx, pid, to!Type(cmd[0]), cmd[1].dup, cmd[2].dup);
					running[pid] = history;
					if(pid in results){
						history.result = results[pid];
					}else if(!exists("/proc/%s".format(pid))){
						history.result = 0;
					}
					if(loaded.canFind(cmd[1] ~ cmd[2]))
						continue;
					loaded ~= cmd[1].idup ~ cmd[2].idup;
					add(history);
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
