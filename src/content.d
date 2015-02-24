module dinu.content;


import
	core.thread,

	std.conv,
	std.process,
	std.string,
	std.array,
	std.algorithm,
	std.stdio,
	std.file,
	std.path,

	desktop,
	dinu.xclient,
	dinu.command;


void loadExecutables(void delegate(Command) addChoice){
	auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
	auto desktops = getAll;
	if((options.configPath ~ ".history").exists){
		size_t idx;
		foreach(line; (options.configPath ~ ".history").readText.splitLines.uniq)
			addChoice(new CommandHistory(line, idx++));
	}
	iterexecs:foreach(line; p.stdout.byLine){
		foreach(match; desktops.find!((a,b)=>a.exec==b)(line)){
			addChoice(new CommandDesktop(match.name, match.exec));
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
}


string unixClean(string path){
	return path
		.replace(" ", "\\ ")
		.replace("(", "\\(")
		.replace(")", "\\)");
}


void loadFiles(string dir, void delegate(Command) addChoice){
	dir = dir.chomp("/") ~ "/";
	Command[] content;
	foreach(i, entry; dir.expandTilde.dirContent(3)){
		string path = buildNormalizedPath(entry.chompPrefix(dir)).unixClean;
		try{
			if(entry.isDir){
				addChoice(new CommandDir(path ~ '/'));
			}else{
				auto attr = getAttributes(path);
				if(attr & (1 + (1<<3)))
					addChoice(new CommandExec(path));
				addChoice(new CommandFile(path));
			}
		}catch(Throwable){}
	}
	writeln("done loading dirs");
}


void loadOutput(void delegate(Command) addChoice){
	try{
		auto log = options.configPath ~ ".log";
		while(!log.exists && (!client || client.running))
			Thread.sleep(100.msecs);
		size_t idx;
		foreach(line; log.readText.splitLines){
			if(!line.canFind("[") && !line.canFind("]"))
				continue;
			auto command = line[line.countUntil("[")+1 .. line.countUntil("]")];
			auto text = line[line.countUntil("]")+1 .. $];
			addChoice(new CommandOutput(command, text, idx++, line.startsWith("ERR ")));
		}
	}catch(Throwable e){
		writeln(e);
	}
}


string[] dirContent(string dir, int depth=int.max){
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


