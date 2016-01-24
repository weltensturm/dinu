module dinu.util;


import
	core.sync.mutex,
	std.string,
	std.regex,
	std.algorithm,
	std.array,
	std.file,
	dinu.dinu,
	dinu.command;

public import ws.math.vector;

__gshared:



string[] bangSplit(string text){
	return text.split(regex(`(?<!\\)\!`)).map!`a.replace("\\!", "!")`.array;
}

string bangJoin(string[] parts){
	return parts.map!`a.replace("!", "\\!")`.join("!");
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


private Mutex logMutex;

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
	}
}

string formatExec(long pid, Type type, string serialized, string parameter){
	return "%s exec %s!%s!%s".format(pid, type, serialized, parameter);
}

void logExec(string text){
	log(text);
	synchronized(logMutex){
		auto path = options.configPath ~ ".exec";
		if(path.exists)
			path.append(text ~ '\n');
		else
			std.file.write(path, text ~ '\n');
	}
}

