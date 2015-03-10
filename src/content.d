module dinu.content;


import
	core.thread,

	std.conv,
	std.regex,
	std.process,
	std.parallelism,
	std.string,
	std.stream,
	std.array,
	std.algorithm,
	std.stdio,
	std.file,
	std.path,

	desktop,
	dinu.dinu,
	dinu.xclient,
	dinu.command;


__gshared:


void loadExecutables(void delegate(Command) addChoice){
	try {
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		auto desktops = getAll;
		iterexecs:foreach(line; p.stdout.byLine){
			foreach(match; desktops.find!((a,b)=>a.exec==b)(line)){
				addChoice(new CommandDesktop([match.name, match.exec ~ " %U"].bangJoin));
				match.name = "";
				continue iterexecs;
			}
			addChoice(new CommandExec(line.to!string));
		}
		foreach(desktop; desktops){
			if(desktop.name.length)
				addChoice(new CommandDesktop([desktop.name, desktop.exec].bangJoin));
		}
		p.pid.wait;
	}catch(Throwable t){
		writeln(t);
	}
}


string unixEscape(string path){
	return path
		.replace(" ", "\\ ")
		.replace("(", "\\(")
		.replace(")", "\\)");
}

string unixClean(string path){
	return path
		.replace("\\ ", " ")
		.replace("\\(", "(")
		.replace("\\)", ")");
}


void loadFiles(string dir, void delegate(Command) addChoice, bool keepPre=false){
	dir = dir.chomp("/") ~ "/";
	Command[] content;
	foreach(i, entry; dir.expandTilde.dirContent(keepPre ? 0 : 2)){
		string path;
		if(keepPre)
			path = buildNormalizedPath(entry).unixClean;
		else
			path = buildNormalizedPath(entry.chompPrefix(dir)).unixClean;
		try{
			if(entry.isDir){
				addChoice(new CommandDir(path.unixEscape));
			}else{
				auto attr = getAttributes(path);
				if(attr & (1 + (1<<3)))
					addChoice(new CommandExec(path.unixEscape));
				addChoice(new CommandFile(path.unixEscape));
			}
		}catch(Throwable t){
			writeln(t);
		}
	}
}


CommandHistory[int] running;
int[int] results;


void matchLine(string line, size_t idx, void delegate(Command) addChoice){
	foreach(match; line.matchAll(`([0-9]+) (\S+)(?: (.*))?`)){
		auto pid = to!int(match.captures[1]);
		if(match.captures[2] == "exec"){
			auto cmd = match.captures[3].bangSplit;
			auto history = new CommandHistory(idx, pid, to!Type(cmd[0]), cmd[1].dup, cmd[2].dup);
			running[pid] = history;
			if(pid in results){
				history.result = results[pid];
			}else if(!exists("/proc/%s".format(pid))){
				history.result = -1;
			}
			addChoice(history);
		}
		if((match.captures[2] == "stdout" || match.captures[2] == "stderr") && match.captures[3].length){
			//if(pid in running)
			addChoice(new CommandOutput(pid, match.captures[3], idx, match.captures[2]=="stderr"));
		}else if(match.captures[2] == "exit"){
			if(pid in running)
				running[pid].result = to!int(match.captures[3]);
			else
				results[pid] = to!int(match.captures[3]);
		}
	}
}


void loadBackwards(void delegate(Command) addChoice, size_t idx){
	auto p = pipeProcess(["tac", options.configPath ~ ".log"], Redirect.stdout);
	foreach(line; p.stdout.byLine){
		matchLine(cast(string)line, idx--, addChoice);
		if(idx<10000-100)
			core.thread.Thread.sleep(1.msecs);
		else if(idx<0 || !client.open)
			return;
	}
	p.pid.wait;
}


void loadOutput(void delegate(Command) addChoice){
	try{
		auto log = options.configPath ~ ".log";
		while(!log.exists || !client || !client.open)
			core.thread.Thread.sleep(100.msecs);
		auto file = new BufferedFile(log);
		file.seekEnd(0);
		//file.position = max(0L, cast(long)file.size-4000L);
		size_t idx = 10000;
		task(&loadBackwards, addChoice, idx).executeInNewThread;
		while(client.open){
			if(!file.eof){
				auto line = cast(string)file.readLine;
				if(!line.length)
					continue;
				matchLine(line, idx++, addChoice);
			}else
				core.thread.Thread.sleep(5.msecs);
		}
	}catch(Throwable e){
		writeln(e);
	}
}


string[] dirContent(string dir, int depth=1){
	string[] subdirs;
	string[] res;
	try{
		foreach(entry; dir.dirEntries(SpanMode.shallow)){
			if(entry.isDir && depth)
				subdirs ~= entry;
			res ~= entry;
		}
	}catch(Throwable e)
		writeln("bad thing ", e);
	foreach(subdir; subdirs)
		res ~= subdir.dirContent(depth-1);
	return res;
}


