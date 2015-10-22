module dinu.content.content;


import
	core.thread,
	core.sys.posix.sys.stat,

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

	ws.x.desktop,
	dinu.dinu,
	dinu.xclient,
	dinu.command;


__gshared:


string[] loadParams(string command){
	bool[string] found;
	auto p = pipeShell(thisExePath.dirName.dirName ~ "/complete.sh '%s'".format(command), Redirect.stdout);
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


string[] dirContent(string dir){
	string[] subdirs;
	string[] res;
	try{
		foreach(entry; dir.dirEntries(SpanMode.shallow)){
			res ~= entry;
		}
	}catch(Throwable e)
		writeln("bad thing ", e);
	return res;
}


class ChoiceLoader {

	protected {
		Command[] loaded;
		void delegate(Command) dg;
		bool active = true;
	}

	this(){
		task({
			try
				run;
			catch(Exception e)
				writeln(e);
		}).executeInNewThread;
	}

	void each(void delegate(Command) dg){
		synchronized(this){
			if(!active)
				return;
			foreach(c; loaded)
				dg(c);
			this.dg = dg;
		}
	}

	void eachComplete(void delegate(Command) dg){
		synchronized(this){
			foreach(c; loaded)
				dg(c);
		}
	}

	void add(Command c){
		synchronized(this){
			if(!active)
				return;
			loaded ~= c;
			if(dg)
				dg(c);
		}
	}

	void run(){
	}

	void stop(){
		synchronized(this){
			if(!active)
				return;
			active = false;
		}
	}

}

