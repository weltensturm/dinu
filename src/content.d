module dinu.content;


import
	core.thread,

	std.conv,
	std.process,
	std.string,
	std.stream,
	std.array,
	std.algorithm,
	std.stdio,
	std.file,
	std.path,

	desktop,
	dinu.xclient,
	dinu.command;


void loadExecutables(void delegate(Command) addChoice){
	try {
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		auto desktops = getAll;
		if((options.configPath ~ ".history").exists){
			size_t idx;
			foreach(line; (options.configPath ~ ".history").readText.splitLines.uniq)
				addChoice(new CommandHistory(line, idx++));
		}
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
		while(!log.exists && (!client || client.running))
			Thread.sleep(100.msecs);
		auto file = new BufferedFile(log);
		size_t idx;
		while(client.running){
			if(!file.eof){
				auto line = cast(string)file.readLine;
				if(!line.canFind("[") && !line.canFind("]"))
					continue;
				auto command = line[line.countUntil("[")+1 .. line.countUntil("]")];
				auto text = line[line.countUntil("]")+1 .. $];
			addChoice(new CommandOutput(command, text, idx++, line.startsWith("ERR ")));
			}else
				Thread.sleep(50.msecs);
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


