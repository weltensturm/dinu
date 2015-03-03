module dinu.content;


import
	core.thread,

	std.conv,
	std.regex,
	std.process,
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


void loadExecutables(void delegate(Command) addChoice){
	try {
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		auto desktops = getAll;
		iterexecs:foreach(line; p.stdout.byLine){
			foreach(match; desktops.find!((a,b)=>a.exec==b)(line)){
				addChoice(new CommandDesktop(match.name, match.exec ~ " %U"));
				match.name = "";
				continue iterexecs;
			}
			addChoice(new CommandExec(line.to!string));
		}
		foreach(desktop; desktops){
			if(desktop.name.length)
				addChoice(new CommandDesktop(desktop.name, desktop.exec));
		}
		p.pid.wait;
		writeln("done loading executables");
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
	writeln("done loading dirs");
}



void loadOutput(void delegate(Command) addChoice){
	try{
		auto log = options.configPath ~ ".log";
		while(!log.exists || !client || !client.open)
			core.thread.Thread.sleep(100.msecs);
		auto file = new BufferedFile(log);
		size_t idx = 1;
		CommandHistory[int] running;
		while(client.open){
			if(!file.eof){
				auto line = cast(string)file.readLine;
				if(!line.length)
					continue;
				foreach(match; line.matchAll(`([0-9]+) (\S+)(?: (.*))?`)){
					auto pid = to!int(match.captures[1]);
					if(match.captures[2] == "exec"){
						auto cmd = match.captures[3].match(`"((?:[^"]|\\")*)" "((?:[^"]|\\")*)" "((?:[^"]|\\")*)"`);
						writeln(cmd);
						auto history = new CommandHistory(cmd.captures[1], cmd.captures[2], cmd.captures[3], idx++);
						running[pid] = history;
						addChoice(history);
					}else if((match.captures[2] == "stdout" || match.captures[2] == "stderr") && match.captures[3].length){
						addChoice(new CommandOutput(running[pid].text, match.captures[3], idx++, match.captures[2]=="stderr"));
					}else if(match.captures[2] == "exit"){
						running[pid].result = to!int(match.captures[3]);
					}
				}
				//auto command = line[line.countUntil("[")+1 .. line.countUntil("]")];
				//auto text = line[line.countUntil("]")+1 .. $];
				//addChoice(new CommandOutput(command, text, idx++, line.startsWith("ERR ")));
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


