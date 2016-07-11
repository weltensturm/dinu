module dinu.loader.executables;


import dinu;


__gshared:


enum ignored = [
	"cd", "clear", "."
];


class ExecutablesLoader: ChoiceLoader {

	override void run(){
		add(new CommandSpecial("cd"));
		add(new CommandSpecial("clear"));
		add(new CommandSpecial("."));
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		auto desktops = getAll;
		iterexecs:foreach(line; p.stdout.byLine){
			if(ignored.canFind(line))
				continue;
			foreach(match; desktops.find!((a,b)=>a.exec==b)(line)){
				add(new CommandDesktop([match.name, match.exec ~ " %U"].bangJoin));
				match.name = "";
				continue iterexecs;
			}
			add(new CommandExec(line.to!string));
		}
		foreach(desktop; desktops){
			if(desktop.name.length)
				add(new CommandDesktop([desktop.name, desktop.exec].bangJoin));
		}

		p.pid.wait;
	}

}
