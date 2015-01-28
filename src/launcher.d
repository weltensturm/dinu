module dinu.launcher;

import
	std.array,
	std.stdio,
	std.range,
	std.string,
	std.conv,
	std.utf,
	std.uni,
	std.algorithm,
	std.parallelism,
	std.process,
	std.file,
	std.path,
	core.thread,
	draw,
	cli,
	dinu.xclient,
	dinu.command,
	desktop;



class Launcher {

	Parameter[] params;
	Parameter currentParam;

	alias currentParam this;

	this(){
		reset;
	}

	void reset(){
		params = [];
		params ~= new ParameterLauncher;
		currentParam = params[0];
	}

	void next(){
		params ~= new ParameterArgument;
		currentParam = params[$-1];
	}

	string finishedPart(){
		string text;
		if(params.length>1)
			foreach(s; params[0..$-1])
				text ~= s.text;
		return text;
	}

	void run(){

		if(toString.startsWith("cd")){
			string cwd = toString[3..$].expandTilde;
			chdir(cwd);
			std.file.write(options.configPath.expandTilde, getcwd);
			reset;
			return;
		}else if(params.length){
			auto command = params[0];
			if(command.selected > -1)
				(cast(Command)command.matches[command.selected]).run("");
			else
				task(&spawnCommand, toString).executeInNewThread;
		}
		throw new Exception("quitting");
	}

	void delBackChar(){
		if(!currentParam.text.length && params.length>1){
			params = params[0..$-1];
			currentParam = params[$-1];
		}
		currentParam.delBackChar;
	}

	void deleteLeft(){
		if(!currentParam.text.length && params.length>1){
			params = params[0..$-1];
			currentParam = params[$-1];
		}
		currentParam.deleteLeft;
	}

	void deleteWordLeft(){
		if(!currentParam.text.length && params.length>1){
			params = params[0..$-1];
			currentParam = params[$-1];
		}
		currentParam.deleteWordLeft;
	}

	override string toString(){
		string text;
		foreach(s; params)
			text ~= s.text;
		return text;
	}

}


class Parameter {

	string text;
	int cursor;
	string filterText;
	int selected = -1;
	Part[] choices;
	Part[] matches;

	void selectNext(){
		if(selected < 0){
			filterText = text;
			selected = -1;
		}
		selected++;
		if(selected==matches.length){
			text = filterText;
			selected = -1;
		}else{
			text = matches[selected].text;
		}
		cursor = cast(int)text.length;
	}

	void filter(){
		matches = choices.filter(selected>-1 ? filterText : text);
	}

	void update(){
		filterText = "";
		selected = -1;
		matches = [];
		if(text.length)
			filter;
	}

	void insert(string s){
		text = text[0..cursor] ~ s ~ text[cursor..$];
		cursor += s.length;
		update;
	}

	void delChar(){
		if(cursor < text.length)
			text = text[0..cursor] ~ text[cursor+1..$];
		update;
	}

	void delBackChar(){
		if(cursor){
			text = text[0..cursor-1] ~ text[cursor..$];
			cursor--;
		}
		update;
	}

	void deleteLeft(){
		text = text[cursor..$];
		cursor = 0;
		update;
	}

	void deleteWordLeft(){
		bool mode = text[cursor-1].isWhite;
		while(cursor && mode == text[cursor-1].isWhite){
			text = text[0..cursor-1] ~ text[cursor..$];
			cursor--;
		}
		update;
	}

	void deleteWordRight(){
		bool mode = text[cursor].isWhite;
		while(cursor && mode == text[cursor-1].isWhite)
			text = text[0..cursor] ~ text[cursor+1..$];
		update;
	}


}


class ParameterArgument: Parameter {

	this(){
		choices = getcwd.entries;
	}

	override void update(){
		super.update;
		choices = getcwd.entries;
		auto dir = text.expandTilde;
		if(dir.exists && dir.isDir)
			choices ~= text.entries;
	}


}


class ParameterLauncher: Parameter {
	
	this(){
		//task(&readCommands).executeInNewThread;
		readCommands;
	}

	override void update(){
		super.update;
		auto dir = text.expandTilde;
		if(dir.exists && dir.isDir)
			choices ~= text.entries;
	}

	void readCommands(){
		choices = getcwd.entries;
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		p.pid.wait;
		auto desktops = getAll;
		iterexecs:foreach(line; p.stdout.byLine){
			foreach(match; desktops.find!((a,b)=>a.exec==b)(line)){
				choices ~= new CommandDesktop(match.name, match.exec);
				match.name = "";
				continue iterexecs;
			}
			choices ~= new CommandExec(line.to!string);
		}
		foreach(desktop; desktops){
			if(desktop.name.length)
				choices ~= new CommandDesktop(desktop.name, desktop.exec);
		}

	}
}


Part[] entries(string dir){
	Part[] content;
	dir = dir.expandTilde;
	string cwd = getcwd;
	foreach(entry; dirEntries(dir, SpanMode.shallow)){
		bool d = entry.isDir;
		string prefix = dir.chompPrefix(cwd).chomp("/");
		if(entry.isDir)
			content ~= new CommandDir(prefix ~ (prefix.length ? "/" : "") ~ entry.baseName);
		else
			content ~= new CommandFile(prefix ~ (prefix.length ? "/" : "") ~ entry.baseName);
	}
	return content;
}


Part[] filter(Part[] what, string with_){
	struct Match {
		int score;
		Part part;
	}
	Match[] matches;
	iter:foreach(entry; what){
		Match match;
		int textIndex;
		int scoreMul = 10;
		foreach(c; entry.filterText){
			if(textIndex < with_.length && with_[textIndex].toLower == c.toLower){
				scoreMul *= (with_[textIndex] != c ? 2 : 4);
				textIndex++;
				match.score += scoreMul;
			}else
				scoreMul = 10;
		}
		if(textIndex == with_.length){
			match.part = entry;
			size_t distance = entry.filterText.levenshteinDistance(with_);
			match.score -= distance;
			if(entry.lessenScore && distance){
				match.score /= 10;
				match.score -= 10;
			}
			matches ~= match;
		}
	}
	matches.sort!((a,b) => a.score-b.score>0);
	Part[] parts;
	foreach(r; matches)
		parts ~= r.part;
	return parts;
}

