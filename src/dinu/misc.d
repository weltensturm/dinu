module dinu.misc;


import dinu;


__gshared:


string[] dirContent(string dir){
	string[] res;
	try{
		foreach(entry; dir.dirEntries(SpanMode.shallow)){
			res ~= entry;
		}
	}catch(Throwable e)
		writeln("bad thing ", e);
	return res;
}


string[] loadBashCompletion(string command){
	bool[string] found;
	writeln(thisExePath);
	auto p = pipeShell("dinu-complete '%s'".format(command), Redirect.stdout);
	string[] result;
	foreach(line; p.stdout.byLine){
		if(line !in found){
			found[line.to!string] = true;
			result ~= line.to!string;
		}
	}
	p.pid.wait;
	return result;
}
