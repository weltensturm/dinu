module dinu.command.history;


import dinu;


__gshared:


class CommandHistory: Command {

	size_t idx;
	long result = long.max;
	Type originalType;
	Command command;

	this(size_t idx, int pid, Type originalType, string serialized, string parameter){
		this.idx = idx;
		this.parameter = parameter;
		type = Type.history;
		switch(originalType){
			case Type.script:
				command = new CommandExec(serialized);
				break;
			case Type.desktop:
				command = new CommandDesktop(serialized);
				break;
			case Type.file:
				command = new CommandFile(serialized);
				break;
			case Type.directory:
				command = new CommandDir(serialized);
				break;
			case Type.special:
				command = new CommandSpecial(serialized);
				break;
			default:
				command = new CommandExec(serialized);
				break;
		}
		this.name = command.text;
	}

	override string filterText(){
		return super.filterText() ~ parameter;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected, int[] positions){
		auto origX = pos.x;
		if(result != long.max){
			if(result)
				dc.rect([pos.x-0.4.em,pos.y], [0.1.em, 1.em], options.colorError);
		}else
			dc.rect([pos.x-0.4.em,pos.y], [0.1.em, 1.em], options.colorHint);
		pos.x += command.draw(dc, pos, selected, positions);
		if(parameter.length)
			pos.x += dc.text(pos, parameter, options.colorOutput);
		return pos.x-origX;
	}

	override void run(){
		auto paramOrig = command.parameter;
		command.parameter ~= parameter;
		command.run;
		command.parameter = paramOrig;
	}

}
