module dinu.command.exec;


import dinu;


__gshared:


shared immutable class CommandExec: Command {

	string[] parts;

	this(string name){
		super(Type.script, name, options.colorExec);
		parts = name.chompPrefix(getcwd ~ "/").split('/');
	}

	this(Type type, string name, float[3] color){
		super(type, name, color);
		parts = [name];
	}

	override string text(){
		return parts.join("/");
	}

	/+override string prepFilter(string filter){
		return filter.expandTilde.absolutePath.buildNormalizedPath;
	}+/

	override size_t score(){
		return 8;
	}

	override int draw(DrawEmpty draw, int[2] pos, bool selected, immutable(int)[] positions){
		foreach(hit; positions){
			auto p = hit - (filterText.length - text.length);
			if(p < text.length){
				auto s = draw.width(text[0..p]);
				draw.setColor([0.333, 0.333, 0.333]);
				draw.rect([pos.x+s, pos.y-3], [draw.width(text[0..p+1])-s, 1.em]);
				//draw.rect([pos.x+s, pos.y+1.em], [draw.width(text[0..p+1])-s, 1], "#999999");
			}
		}

		int advance = 0;
		foreach(i, part; parts){
			if(i+1 < parts.length){
				draw.setColor(options.colorDir);
				advance += draw.text([pos.x+advance, pos.y], part, 0);
				draw.setColor(options.colorOutput);
				advance += draw.text([pos.x+advance, pos.y], "/", 0);
			}else{
				draw.setColor(options.colorExec);
				advance += draw.text([pos.x+advance, pos.y], part, 0);
			}
		}
		return advance;
	}

	override void run(string parameter){
		spawnCommand(name, parameter);
	}

}
