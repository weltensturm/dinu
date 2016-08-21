module dinu.command.desktop;


import dinu;


__gshared:


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

	override int draw(DrawingContext dc, int[2] pos, bool selected, int[] positions){
		int origX = pos.x;
		pos.x += super.draw(dc, pos, selected, positions);
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
