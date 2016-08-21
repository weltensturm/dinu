module dinu.command.output;


import dinu;


__gshared:


class CommandOutput: Command {
	
	size_t idx;
	string command;
	int pid;

	this(int pid, string output, size_t idx, bool err){
		super(output);
		type = Type.output;
		this.pid = pid;
		this.idx = idx;
		if(err)
			color = options.colorError;
		else
			color = options.colorOutput;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected, int[] positions){
		if(!command.length && pid in running)
			command = running[pid].text;

		dc.text(pos, command, options.colorHint, 1.8);
		return super.draw(dc, pos, selected, positions);
	}

	override void run(){}

}
