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
	std.math,
	std.datetime,
	core.thread,
	core.sync.condition,
	draw,
	cli,
	dinu.xclient,
	dinu.command,
	desktop;


__gshared:


/+
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
+/

ChoiceFilter choiceFilter;


class Launcher {

	CommandPicker command;
	Picker[] params;
	Picker currentParam;

	alias currentParam this;

	this(){
		reset;
	}

	void reset(){
		choiceFilter = new ChoiceFilter;
		command = new CommandPicker;
		params = [];
		currentParam = command;
	}

	void next(){
		params ~= new Picker;
		choiceFilter.reset("");
		currentParam = params[$-1];
	}

	string finishedPart(){
		if(params.length)
			return reduce!"a ~ b.text"(command.command.text ~ ' ', params[0..$-1]);
		return "";
	}

	void run(){
		if(!command.command)
			command.finishPart;
		if(toString.startsWith("cd ")){
			string cwd = toString[3..$].expandTilde;
			chdir(cwd);
			std.file.write(options.configPath.expandTilde, getcwd);
			reset;
			return;
		}else if(command.command){
			command.command.run(reduce!"a ~ b.text"("", params));
		}
		throw new Exception("bye");
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
		if(!currentParam)
			command.deleteLeft;
	}

	void deleteWordLeft(){
		if(!currentParam.text.length && params.length>1){
			params = params[0..$-1];
			currentParam = params[$-1];
		}
		currentParam.deleteWordLeft;
	}

	override string toString(){
		return reduce!"a ~ b.text"(command.text, params);
	}

}


class Picker {

	string text;
	long cursor;
	string filterText;
	long selected;

	this(){
		setSelected(-1);
	}

	override string toString(){
		return text;
	}

	protected void setSelected(long selected){
		auto res = choiceFilter.res;
		if(selected >= res.length)
			selected = -1;
		else if(selected < -1)
			selected = cast(long)res.length-1;
		if(selected != -1){
			if(!filterText.length)
				filterText = text;
			text = res[selected].data.text;
		}else if(filterText.length){
			text = filterText;
			filterText = "";
		}
		this.selected = selected;
	}

	void selectNext(){
		setSelected(selected+1);
		cursor = cast(int)text.length;
	}

	void selectPrev(){
		setSelected(selected-1);
		cursor = cast(int)text.length;
	}

	void update(){
		filterText = "";
		setSelected(-1);
	}

	void finishPart(){
		launcher.next;
	}

	void onDel(){
		update;
		choiceFilter.reset(text);
	}

	void insert(string s){
		bool clean = !text.length;
		text = text[0..cursor] ~ s ~ text[cursor..$];
		cursor += s.length;
		if(clean)
			choiceFilter.reset(text);
		else
			choiceFilter.narrow(s);
		if(s == " " && text.length && text[$-1] != '\\'){
			finishPart;
		}else
			update;
	}

	void delChar(){
		if(cursor < text.length)
			text = text[0..cursor] ~ text[cursor+1..$];
		onDel;
	}

	void delBackChar(){
		if(cursor){
			text = text[0..cursor-1] ~ text[cursor..$];
			cursor--;
		}
		onDel;
	}

	void deleteLeft(){
		text = text[cursor..$];
		cursor = 0;
		onDel;
	}

	void deleteWordLeft(){
		if(!text.length)
			return;
		bool mode = text[cursor-1].isWhite;
		while(cursor && mode == text[cursor-1].isWhite){
			text = text[0..cursor-1] ~ text[cursor..$];
			cursor--;
		}
		onDel;
	}

	void deleteWordRight(){
		bool mode = text[cursor].isWhite;
		while(cursor && mode == text[cursor-1].isWhite)
			text = text[0..cursor] ~ text[cursor+1..$];
		onDel;
	}


}


class CommandPicker: Picker {

	Command command;

	this(){
		setSelected(0);
	}

	override protected void finishPart(){
		choiceFilter.wait;
		command = choiceFilter.res[selected<0 ? 0 : selected].data;
		text = command.text ~ ' ';
		cursor = text.length;
		launcher.next;
	}

	override protected void setSelected(long selected){
		auto res = choiceFilter.res;
		if(selected >= res.length)
			selected = 0;
		else if(selected < 0)
			selected = cast(int)res.length-1;
		this.selected = selected;
	}


}


class ChoiceFilter {

	protected {

		Command[] all;
		Match[] matches;
		string filter;
		string narrowQueue;
		void delegate() waitLoad;

		struct Match {
			long score;
			Command data;
		}

		long filterStart;

		Thread filterThread;
		bool restart;
		bool idle = true;

		string typeFilter;

	}

	this(){
		auto taskExes = task(&loadExecutables, &addChoice);
		auto taskFiles = task(&loadFiles, getcwd, &addChoice);
		taskExes.executeInNewThread;
		taskFiles.executeInNewThread;
		waitLoad = {
			while(!taskExes.done || !taskFiles.done)
				Thread.sleep(10.msecs);
		};
		filterThread = new Thread(&filterLoop);
		filterThread.start;
	}

	void wait(){
		writeln("waiting");
		waitLoad();
		while(!idle)
			Thread.sleep(10.msecs);
		idle = false;
		writeln("done");
		//writeln(matches);
		foreach(m; all){
			if(m.text == "cd")
				writeln(m.text);
		}
		idle = true;
	}

	void reset(string filter){
		if(filter.startsWith("!", "@")){
			typeFilter = ""~filter[0];
			filter = filter[1..$];
		}else
			typeFilter = "";
		restart = true;
		synchronized(this){
			narrowQueue = "";
			this.filter = filter;
		}
	}

	void narrow(string text){
		synchronized(this)
			narrowQueue ~= text;
	}

	Match[] res(){
		return matches;
	}

	void run(int selected, string args){
		matches[selected].data.run(args);
	}

	protected {

		void intReset(string filter){
			if(!idle)
				throw new Exception("already working");
			idle = false;
			this.filter = filter;
			synchronized(this)
				matches = [];
			filterStart = Clock.currSystemTick.seconds;
			Command[] allCpy;
			synchronized(this)
				allCpy = all.dup;
			foreach(m; allCpy)
				tryMatch(m);
			idle = true;
		}

		void intNarrow(string filter){
			if(!idle)
				throw new Exception("already working");
			idle = false;
			synchronized(this)
				this.filter = filter;
			Match[] mdup;
			synchronized(this){
				mdup = matches;
				matches = [];
			}
			filterStart = Clock.currSystemTick.seconds;
			foreach(m; mdup){
				tryMatch(m.data);
				if(restart)
					break;
			}
			idle = true;
		}

		void addChoice(Command p){
			synchronized(this)
				all ~= p;
			tryMatch(p);
		}

		void tryMatch(Command p){
			if(typeFilter == "!" && p.type != Type.desktop && p.type != Type.script)
				return;
			if(typeFilter == "@" && p.type != Type.file && p.type != Type.directory)
				return;
			Match match;
			match.score = p.filterText.cmpFuzzy(filter)+p.score;
			if(match.score > 0){
				match.data = p;
				synchronized(this){
					foreach(i, e; matches){
						if(e.score < match.score){
							matches = matches[0..i] ~ match ~ matches[i..$];
							client.sendUpdate;
							return;
						}
					}
					matches = matches ~ match;
				}
				client.sendUpdate;
			}
		}

		void filterLoop(){
			filterThread.isDaemon = true;
			try{
				while(true || client.running){
					if(narrowQueue.length){
						synchronized(this){
							writeln("narrow queue ", narrowQueue, " ", typeFilter);
							filter ~= narrowQueue;
							narrowQueue = "";
						}
						intNarrow(filter);
						client.sendUpdate;
					}else if(restart){
						writeln("restart ", filter, " ", typeFilter);
						intReset(filter);
						restart = false;
						client.sendUpdate;
					}else{
						Thread.sleep(15.msecs);
						client.sendUpdate;
					}
				}
			}catch(Throwable t)
				writeln(t);
		}
	
	}

}


void loadExecutables(void delegate(Command) addChoice){
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
	p.pid.wait;
	writeln("done loading executables");
}


string unixClean(string path){
	return path
		.replace(" ", "\\ ")
		.replace("(", "\\(")
		.replace(")", "\\)");
}


void loadFiles(string dir, void delegate(Command) addChoice){
	dir = dir.chomp("/") ~ "/";
	Command[] content;
	foreach(i, entry; dir.expandTilde.dirContent(3)){
		string path = buildNormalizedPath(entry.chompPrefix(dir)).unixClean;
		try{
			if(entry.isDir){
				addChoice(new CommandDir(path ~ '/'));
			}else{
				auto attr = getAttributes(path);
				if(attr & (1 + (1<<3)))
					addChoice(new CommandExec(path));
				addChoice(new CommandFile(path));
			}
		}catch(Throwable){}
	}
	writeln("done loading dirs");
}


string[] dirContent(string dir, int depth=int.max){
	string[] subdirs;
	string[] res;
	try{
		foreach(entry; dir.dirEntries(SpanMode.shallow)){
			if(entry.isDir && depth)
				subdirs ~= entry;
			res ~= entry;
		}
	}catch(Throwable e)
		writeln("bad thing ", e);
	foreach(subdir; subdirs)
		res ~= subdir.dirContent(depth-1);
	return res;
}


long cmpFuzzy(string str, string sub){
	long scoreMul = 100;
	long score = scoreMul*10;
	long curIdx;
	long largestScore;
	foreach(i, c; str){
		if(curIdx<sub.length && c.toLower == sub[curIdx].toLower){
			scoreMul *= (c == sub[curIdx] ? 4 : 3);
			score += scoreMul;
			curIdx++;
		}else{
			scoreMul = 100;
		}
		if(curIdx==sub.length){
			scoreMul = 100;
			curIdx = 0;
			score = scoreMul*10;
			if(largestScore < score-i+sub.length)
				largestScore = score-i+sub.length;
		}
	}
	//score -= phoneticalScore(str);
	//score -= abs(sub.icmp(str));
	//writeln(total, ' ', str, ' ', scores);
	if(!largestScore)
		return 0;
	largestScore -= sub.levenshteinDistance(str)*4;
	if(!sub.startsWith(".") && (str.canFind("/.") || str.startsWith(".")))
		largestScore -= 100;
	if(sub == str)
		largestScore += 10000000;
	return largestScore;
}


long phoneticalScore(string str){
	long score = 0;
	foreach(i, c; str){
		score += cast(long)c / (i*5 + 1);
	}
	return score;
}


unittest {
	assert("asbsdf".cmpFuzzy("asdf") > "absdf".cmpFuzzy("asdf"));
	assert("dlist-edgeflag-dangling".cmpFuzzy("pidgin") == 0);
}

/+
class Filter {

	struct Match {
		size_t score;
		Part data;
	}

	protected string filter;
	protected Match[] found;
	protected Thread filterThread;
	protected bool restart;

	void filter(Part[] haystack, string needle){
		if(filterThread){
			restart = true;
			filterThread.join;
			restart = false;
			found = [];
		}
		filterThread = new Thread({filterFun(haystack, needle);});
		filterThread.start;
	}

	Match[] matches(){
		synchronized(this)
			return found;
	}


	void filterText(string text){

	}

	protected void filterFun(Part[] haystack, string needle){
		foreach(hay; haystack){
			addChoice(hay);
			if(restart)
				return;
		}
	}

	void addChoice(Part data){
		Match match;
		match.score = data.text.cmpFuzzy(needle)*data.score;
		if(match.score > 0){
			match.data = hay;
			if(!found.length)
				synchronized(this)
					found ~= match;
			else
				foreach(i, e; found){
					if(e.score < match.score || i == found.length-1){
						synchronized(this)
							found = found[0..i] ~ match ~ found[i..$];
						writeln(match.score, ' ', match.data.text);
						break;
					}
				}
		}
	}

	/+
	void filter(Part[] what, string with_){
		struct Match {
			int score;
			Part part;
		}
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
				match.score -= distance*2;
				if(!distance)
					match.score += 100000;
				//match.score -= abs(entry.filterText[0]-with_[0]);
				found ~= match;
			}
		}
		matches.sort!((a,b) => a.score>b.score);
		Part[] parts;
		foreach(r; matches){
			parts ~= r.part;
		}
		return parts;
	}
	+/

}


+/


