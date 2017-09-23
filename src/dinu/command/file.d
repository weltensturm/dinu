module dinu.command.file;


import dinu;


string chompAll(string source, string what){
	while(source.chomp(what) != source)
		source = source.chomp(what);
	return source;
}


shared immutable class CommandFile: Command {

	bool home;
	string[] parts;

	private this(){
		super(Type.file, "");
		parts = [];
		home = false;
	}

	this(string name){
		this(Type.file, name);
	}

	this(Type type, string name, bool isDir=false){
		super(type, name.unixEscape, options.colorFile);
		if(isDir)
			parts = (name.chompPrefix(getcwd ~ "/") ~ "/").split('/');
		else
			parts = name.chompPrefix(getcwd ~ "/").split('/');
		home = (
			name.chompPrefix("~".expandTilde) != name
			|| !name.startsWith("/") && getcwd == "~".expandTilde
		);
	}

	override string text(){
		return parts.join("/");
	}

	override string prepFilter(string filter){
		if(!filter.length)
			return "";
		auto slashes = filter.length - filter.chompAll("/").length;
		if(filter.startsWith(".."))
			return filter.expandTilde.absolutePath.buildNormalizedPath ~ "/".replicate(slashes);
		else
			return filter.expandTilde.buildNormalizedPath ~ "/".replicate(slashes);
	}

	override size_t score(){
		return 10;
	}

	override int draw(XDraw draw, int[2] pos, bool selected, immutable(int)[] positions){
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
				draw.setColor(options.colorFile);
				advance += draw.text([pos.x+advance, pos.y], part, 0);
			}
		}
		return advance;
	}

	override void run(string){
		options.configPath.openFile(name);
	}

}
