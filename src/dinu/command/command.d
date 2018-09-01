module dinu.command.command;


import dinu;


__gshared:


enum Type {

	none,
	script,
	desktop,
	history,
	file,
	directory,
	output,
	special,
	bashCompletion,
	processInfo,
	window

}


shared immutable class Command {

	string name;
	Type type;
	float[3] color;
	float[3] colorInput;
	string parameter;

	protected this(Type type, string name, string parameter = ""){
		this.type = type;
		this.name = name;
		this.parameter = parameter;
		color = options.colorFile;
		colorInput = options.colorInput;
	}

	protected this(Type type, string name, float[3] color, string parameter = ""){
		this(type, name, parameter);
		this.color = color;
	}

	string serialize(){
		return name;
	}

	string text(){
		return name;
	}

	string prepFilter(string filter){
		return filter;
	}

	string filterText(){
		return name;
	}

	string hint(){
		return "";
	}

	size_t score(){
		return 0;
	}

	void run(){ run(parameter); }
	abstract void run(string);

	int draw(DrawEmpty draw, int[2] pos, bool selected, immutable(int)[] positions){
		int origX = pos.x;

		foreach(p; positions){
			if(p < text.length){
				auto s = draw.width(text[0..p]);
				draw.setColor([0.333, 0.333, 0.333]);
				draw.rect([pos.x+s, pos.y-3], [draw.width(text[0..p+1])-s, 1.em]);
			}
		}

		draw.setColor(color);
		pos.x += draw.text(pos, text, 0);
		draw.setColor(colorInput);
		if(parameter.length)
			pos.x += draw.text(pos, ' ' ~ parameter, 0);
		return pos.x-origX;
	}

	void spawnCommand(string command, string arguments=""){
		options.configPath.execute(
			type.to!string,
			serialize.replace("!", "\\!"),
			command,
			arguments.replace("!", "\\!")
		);
	}

}

