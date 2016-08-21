module dinu.command.file;


import dinu;


__gshared:


class CommandFile: Command {

	immutable bool home;

	private this(){home=false;}

	this(string name){
		this.name = name.unixEscape;
		type = Type.file;
		color = options.colorFile;
		parts = name.chompPrefix(getcwd ~ "/").split('/');
		home = (
			name.chompPrefix("~".expandTilde) != name
			|| !name.startsWith("/") && getcwd == "~".expandTilde
		);
	}

	string[] parts;

	override string text(){
		return parts.join("/");
	}

	override string filterText(){
		return name;
	}

	override size_t score(){
		return 10;
	}

	override int draw(DrawingContext dc, int[2] pos, bool selected, int[] positions){
		foreach(p; positions){
			p -= (filterText.length - text.length);
			if(p < text.length){
				auto s = dc.textWidth(text[0..p]);
				dc.rect([pos.x+s, pos.y], [dc.textWidth(text[0..p+1])-s, 1.em], "#555555");
				//dc.rect([pos.x+s, pos.y+1.em], [dc.textWidth(text[0..p+1])-s, 1], "#999999");
			}
		}

		int advance = 0;
		foreach(i, part; parts){
			if(i+1 < parts.length){
				advance += dc.text([pos.x+advance, pos.y], part, options.colorDir);
				advance += dc.text([pos.x+advance, pos.y], "/", options.colorOutput);
			}else
				advance += dc.text([pos.x+advance, pos.y], part, options.colorFile);
		}
		return advance;
	}

	override void run(){
		options.configPath.openFile(name);
	}

}
