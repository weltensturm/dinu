module dinu.command.history;


import dinu;


shared immutable class CommandHistory: Command {

	Type originalType;
	Command command;
	int pid;

	this(int pid, Type originalType, string serialized, string parameter){
		this.originalType = originalType;
		this.pid = pid;
		if(originalType == Type.script)
			command = new immutable CommandExec(serialized);
		else if(originalType == Type.desktop)
			command = new immutable CommandDesktop(serialized);
		else if(originalType == Type.file)
			command = new immutable CommandFile(serialized);
		else if(originalType == Type.directory)
			command = new immutable CommandDir(serialized);
		else if(originalType == Type.special)
			command = new immutable CommandSpecial(serialized);
		else
			command = new immutable CommandExec(serialized);
		super(Type.history, command.text, parameter);
	}

	override string filterText(){
		return command.filterText() ~ parameter;
	}

	override string hint(){
		auto result = running[pid].result;
		return result == long.max ? "~" : result.to!string; //command.hint;
	}

	override size_t score(){
		return commandBuilder.text.length
				? (parameter.length == 0 ? 0 : command.score)
				: command.score*10;
		//return commandBuilder.text.length ? command.score : 20 + running[pid].occurrences;
	}

	override int draw(DrawEmpty draw, int[2] pos, bool selected, immutable(int)[] positions){
		auto origX = pos.x;
		/+
		if(auto r = (pid in running)){
			if(r.result != long.max){
				if(r.result)
					draw.setColor(options.colorError);
					draw.rect([pos.x-0.4.em, pos.y-3], [0.1.em, 1.em]);
			}else
				draw.setColor(options.colorHint);
				draw.rect([pos.x-0.4.em, pos.y-3], [0.1.em, 1.em]);
		}
		+/
		pos.x += command.draw(draw, pos, selected, positions);
		if(parameter.length)
			draw.setColor(options.colorOutput);
			pos.x += draw.text(pos, parameter);
		return pos.x-origX;
	}

	override void run(string parameter){
		command.run(parameter);
	}

}

