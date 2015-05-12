module dinu.content.executables;


import
	std.process,
	std.algorithm,
	std.conv,
	std.file,
	std.path,
	std.string,
	std.array,
	dinu.dinu,
	dinu.util,
	dinu.content.content,
	dinu.command,
	desktop,
	draw;


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

class CommandExec: Command {

	this(string name){
		this.name = name;
		type = Type.script;
		color = options.colorExec;
	}

	override size_t score(){
		return 5;
	}

	override void run(){
		spawnCommand(name, parameter);
	}

}

class CommandSpecial: CommandExec {

	this(string name){
		super(name);
		this.name = name;
		type = Type.special;
		color = options.colorExec;

	}

	override void run(){
		final switch(name){
			case "cd":
				chdir(parameter.expandTilde.unixClean);
				std.file.write(options.configPath, getcwd);
				log("%s exec %s!%s!%s".format(0, Type.special, serialize.replace("!", "\\!"), parameter.replace("!", "\\!")));
				break;
			case "clear":
				commandBuilder.clearOutput;
				break;
			case ".":
				this.spawnCommand("xdg-open .", "");
				break;
		}
	}

}

class CommandDesktop: Command {

	string exec;

	this(string args){
		auto split = args.bangSplit;
		name = split[0];
		exec = split[1];
		color = options.colorDesktop;
		type = Type.desktop;
	}

	override string serialize(){
		return [name, exec].bangJoin;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected){
		int origX = pos.x;
		pos.x += super.draw(dc, pos, selected);
		//pos.x += dc.text(pos, exec, options.colorHint);
		return pos.x-origX;
	}

	override string hint(){
		return exec;
	}

	override size_t score(){
		return 7;
	}

	override string filterText(){
		return name ~ exec;
	}

	override void run(){
		this.spawnCommand(exec.replace("%f", parameter).replace("%F", parameter).replace("%u", parameter).replace("%U", parameter));
	}

}
