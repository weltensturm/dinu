module dinu.util;


import
	core.sync.mutex,
	std.string,
	std.regex,
	std.algorithm,
	std.array,
	std.file,
	dinu.dinu;


__gshared:


ref T x(T)(ref T[2] a){
	return a[0];
}
alias w = x;

ref T y(T)(ref T[2] a){
	return a[1];
}
alias h = y;


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

