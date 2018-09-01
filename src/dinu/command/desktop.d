module dinu.command.desktop;


import dinu;


__gshared:


shared immutable class CommandDesktop: Command {

	string exec;

	this(string args){
		auto split = args.bangSplit;
		super(Type.desktop, split[0], options.colorDesktop);
		exec = split[1];
	}

	override string serialize(){
		return [name, exec].bangJoin;
	}

	override int draw(DrawEmpty draw, int[2] pos, bool selected, immutable(int)[] positions){
		int origX = pos.x;
		pos.x += super.draw(draw, pos, selected, positions);
		return pos.x-origX;
	}

	override string hint(){
		return exec;
	}

	override size_t score(){
		return 12;
	}

	override string filterText(){
		return name ~ exec;
	}

	override void run(string parameter){
		this.spawnCommand(
				exec.replace("%f", parameter)
					.replace("%F", parameter)
					.replace("%u", parameter)
					.replace("%U", parameter)
		);
	}

	override void spawnCommand(string command, string arguments=""){
		options.configPath.execute(type.to!string, serialize.replace("!", "\\!"), command, arguments.replace("!", "\\!"));
	}

}
