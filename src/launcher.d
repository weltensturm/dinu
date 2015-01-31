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


__gshared:



string[] getCompletions(string partial){
	string trigger = "true || %s".format(partial);
	auto pipes = pipeShell(`echo -e "%s\t\t" | bash -i`.format(trigger));
	string output;
	foreach(line; pipes.stderr.byLine)
		output ~= line ~ '\n';
	output = output[output.indexOf(trigger)+trigger.length..$];
	if(output.canFind(trigger))
		output = output[0..output.indexOf(trigger)];
	writeln(output);
	return [output];
}


class LauncherCompleter: Launcher {

	Command[] choices;
	size_t selected;

	this(){
		
	}

	void addCommand(Command c){

	}

}


class Launcher {

	Picker[] params;
	Picker currentParam;

	alias currentParam this;

	this(){
		reset;
	}

	void reset(){
		params = [];
		params ~= new PickerCommand;
		currentParam = params[0];
	}

	void checkReceived(){
		if(currentParam.text.length)
			currentParam.filter;
	}

	void next(){
		params ~= new PickerPath;
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


class Picker {

	string text;
	int cursor;
	string filterText;
	int selected = -1;
	Part[] choices;
	Part[] matches;
	string[] pathsScanned;
	bool loading;

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
		filter;
	}

	void filter(){
		matches = choices.filter(selected>-1 ? filterText : text);
	}

	void update(){
		filterText = "";
		selected = -1;
		matches = [];
		//getCompletions(launcher.toString);
		if(text.length)
			filter;
	}

	void insert(string s){
		text = text[0..cursor] ~ s ~ text[cursor..$];
		cursor += s.length;
		update;
		if(s == " " && s[$-1] != '\\' || s == "=")
			launcher.next;
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


	Part[] entries(string dir){
		if(pathsScanned.canFind(dir.chomp("/")))
			return [];
		pathsScanned ~= dir.chomp("/");
		Part[] content;
		string cwd = getcwd;
		foreach(entry; dirEntries(dir.expandTilde, SpanMode.shallow)){
			bool d = entry.isDir;
			string path = buildNormalizedPath(dir.chompPrefix(cwd), entry.baseName).replace(" ", "\\ ");
			if(entry.isDir){
				content ~= new CommandDir(path);
			}else
				content ~= new CommandFile(path);
		}
		return content;
	}



}


class PickerPath: Picker {

	this(){
		choices = entries(getcwd);
	}

	override void update(){
		auto dir = text.expandTilde;
		if(dir.exists && dir.isDir)
			choices ~= entries(text);
		super.update;
	}


}


class PickerCommand: Picker {

	CommandLoader commandLoader;

	this(){
		//commandLoader = new CommandLoader;
		synchronized(this)
			choices = entries(getcwd);
		loading = true;
		task(&readCommands).executeInNewThread;
		//readCommands;
	}

	override void update(){
		auto dir = text.expandTilde;
		if(dir.exists && dir.isDir)
			synchronized(this)
				choices ~= entries(text);
		super.update;
	}

	void readCommands(){
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		auto desktops = getAll;
		iterexecs:foreach(line; p.stdout.byLine){
			foreach(match; desktops.find!((a,b)=>a.exec==b)(line)){
				addChoice(new CommandDesktop(match.name, match.exec));
				match.name = "";
				continue iterexecs;
			}
			addChoice(new CommandExec(line.to!string));
		}
		foreach(desktop; desktops){
			if(desktop.name.length)
				addChoice(new CommandDesktop(desktop.name, desktop.exec));
		}
		if("~/.bin".expandTilde.exists){
			foreach(entry; "~/.bin".expandTilde.dirEntries(SpanMode.shallow))
				addChoice(new CommandUserExec(entry.baseName));
		}
		p.pid.wait;
		loading = false;
		client.sendUpdate;
	}

	void addChoice(Part part){
		synchronized(this)
			choices ~= part;
		if(!(choices.length % 10))
			client.sendUpdate;
		//Thread.sleep(5.msecs);
	}

}


synchronized class CommandLoader {

	bool loading = true;

	this(){

	}

	void findAll(){

		loading = false;
	}

	void foundSomething(){
	}

}


Part[] filter(Part[] what, string with_){
	struct Match {
		int score;
		Part part;
	}
	Match[] matches;
	foreach(entry; what){
		Match match;
		int textIndex;
		int scoreMul = entry.score;
		foreach(c; entry.filterText){
			if(textIndex < with_.length && with_[textIndex].toLower == c.toLower){
				scoreMul *= (with_[textIndex] != c ? 2 : 4);
				textIndex++;
				match.score += scoreMul;
			}else
				scoreMul = entry.score;
		}
		if(textIndex == with_.length && with_.length){
			match.part = entry;
			size_t distance = entry.filterText.levenshteinDistance(with_);
			match.score -= distance;
			if(!distance)
				match.score += 100000;
			match.score -= (entry.filterText[0]-with_[0]);
			matches ~= match;
		}
	}
	matches.sort!((a,b) => a.score>b.score);
	Part[] parts;
	foreach(r; matches){
		parts ~= r.part;
	}
	return parts;
}

