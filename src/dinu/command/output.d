module dinu.command.output;


import dinu;


shared immutable class CommandOutput: Command {
	
	size_t idx;
	//string command;
	int pid;

	this(int pid, string output, size_t idx, bool err){
		super(Type.output, output, err ? options.colorError : options.colorOutput);
		this.pid = pid;
		this.idx = idx;
	}

	override size_t score(){
		return idx*1000;
	}

	override int draw(XDraw draw, int[2] pos, bool selected, immutable(int)[] positions){
		/+
		if(!command.length && pid in running)
			command = running[pid].text;
		draw.setColor(options.colorHint);
		draw.text(pos, command, 1.8);
		+/
		return super.draw(draw, pos, selected, positions);
	}

	override void run(){}
	override void run(string){}

}
