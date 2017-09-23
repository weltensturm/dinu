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
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		auto desktops = getAll;
		iterexecs:foreach(line; p.stdout.byLine){
			if(ignored.canFind(line))
				continue;
			foreach(match; desktops.find!((a,b)=>a.exec==b)(line)){
				add(new immutable CommandDesktop([match.name, match.exec ~ " %U"].bangJoin));
				match.name = "";
				continue iterexecs;
			}
			add(new immutable CommandExec(line.to!string));
		}
		foreach(desktop; desktops){
			if(desktop.name.length)
				add(new immutable CommandDesktop([desktop.name, desktop.exec].bangJoin));
		}

		p.pid.wait;
	}

}
