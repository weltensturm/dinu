module dinu.loader.executables;


import dinu;


__gshared:


enum ignored = [
	"cd", "clear", "."
];


class ExecutablesLoader: ChoiceLoader {

	override void run(){
		add(new immutable CommandSpecial("cd"));
		add(new immutable CommandSpecial("clear"));
		add(new immutable CommandSpecial("."));
		
		auto execs = pipeShell("compgen -ack -A function | sort -u", Redirect.stdout);

		auto desktops = getAll;

		string[] ignoreExecs;

		foreach(desktop; desktops){
			auto executable = desktop.exec;
			foreach(c; "fFuU")
				executable = executable.replace("%" ~ c, "").strip;
			if(!executable.length)
				continue;
			ignoreExecs ~= executable;
			add(new immutable CommandDesktop([desktop.name, executable].bangJoin));
		}

		foreach(executable; execs.stdout.byLineCopy){
			if(!executable.length || ignored.canFind(executable) || ignoreExecs.canFind(executable))
				continue;
			add(new immutable CommandExec(executable));
		}

	}

}
