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
	dinu.dinu,
	dinu.xclient,
	dinu.content,
	dinu.command;


__gshared:


ChoiceFilter choiceFilter;
ChoiceFilter output;


class Launcher {

	CommandPicker command;
	Picker[] params;
	Picker currentParam;
	int logIdx=1;

	alias currentParam this;

	this(){

		choiceFilter = new ChoiceFilter((c){
			if(choiceFilter && choiceFilter.commandHistory){
				return c.type == Type.history;
			}else if(launcher && launcher.text.length){
				auto filter = [Type.file, Type.directory];
				if(launcher && !launcher.params.length)
					filter ~= [Type.script, Type.desktop, Type.special];
				return filter.canFind(c.type);
			}
			return false;
		});

		output = new ChoiceFilter((c){
			return c.type == Type.output || c.type == Type.history;
		});

		reset;
	}

	void reset(Type mode = Type.none){
		params = [];
		command = new CommandPicker;
		currentParam = command;
		choiceFilter.commandHistory = false;
		choiceFilter.reset("", mode);
	}

	void toggleCommandHistory(){
		choiceFilter.commandHistory = true;
		choiceFilter.reset;
	}

	void next(){
		params ~= new Picker;
		choiceFilter.commandHistory = false;
		choiceFilter.reset;
		currentParam = params[$-1];
	}

	string finishedPart(){
		if(params.length)
			return reduce!"a ~ b.text"(command.command.text ~ ' ', params[0..$-1]);
		return "";
	}

	void clearOutput(){
		std.file.write(options.configPath ~ ".log", "");
		output.output = [];
	}

	void run(bool res=true){
		if(!command.command){
			command.finishPart;
			if(command.selected<0){
				return;
			}
		}
		if(command.command){
			command.command.run(reduce!"a ~ b.text"("", params));
			if(res)
				choiceFilter.startOver;
		}
		if(res)
			reset;
	}

	void delBackChar(){
		if(!currentParam.text.length){
			if(params.length>1){
				params = params[0..$-1];
				currentParam = params[$-1];
			}else{
				params = [];
				currentParam = command;
			}
		}
		currentParam.delBackChar;
	}

	void deleteLeft(){
		reset;
	}

	void deleteWordLeft(){
		if(!currentParam.text.length){
			if(params.length>1){
				params = params[0..$-1];
				currentParam = params[$-1];
			}else{
				params = [];
				currentParam = command;
			}
		}
		currentParam.deleteWordLeft;
	}

	override string toString(){
		return reduce!"a ~ b.text"(command.text, params);
	}

}


class Picker {

	string text;
	size_t cursor;
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
		auto output = output.res;
		if(selected >= cast(long)res.length || selected < -1-cast(long)output.length)
			selected = -1;
		if(selected > -1){
			if(!filterText.length)
				filterText = text;
			text = res[cast(size_t)selected].data.text;
		}else if(selected < -1){
			if(!filterText.length)
				filterText = text;
			text = output[cast(size_t)(-selected-2)].data.text;
		}else if(filterText.length){
			text = filterText;
			filterText = "";
		}
		this.selected = selected;
	}

	void selectNext(){
		setSelected(selected+1);
		cursor = text.length;
	}

	void selectPrev(){
		writeln(selected-1);
		setSelected(selected-1);
		cursor = text.length;
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
		if(!text.length)
			choiceFilter.commandHistory = false;
		choiceFilter.reset(text);
	}

	void insert(string s){
		bool clean = !text.length;
		text = text[0..cursor] ~ s ~ text[cursor..$];
		cursor += s.length;
		if(clean || selected >= 0)
			choiceFilter.reset(text);
		else
			choiceFilter.narrow(s);
		if(s == " " && (cursor<2 || text[cursor-2] != '\\')){
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
		setSelected(-1);
	}

	override void onDel(){
		super.onDel;
		if(!text.length)
			setSelected(-1);
	}

	override protected void finishPart(){
		if(!text.length && selected<0)
			return;
		choiceFilter.wait;
		if(!choiceFilter.res.length){
			command = new CommandExec(text);
		}else{
			selected = (selected<0 ? 0 : selected);
			command = choiceFilter.res[cast(size_t)selected].data;
		}
		text = command.text ~ ' ';
		cursor = text.length;
		launcher.next;
	}

}


class ChoiceFilter {

	protected {

		Command[] output;
		Command[] permanent;
		Command[] temporary;
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

		string[] scannedDirs;
		string[] scannedDirsTemp;

		bool delegate(Command) filterFunc;

	}

	bool commandHistory;

	this(bool delegate(Command) filterFunc){
		task(&loadOutput, (Command c){
			synchronized(this)
				output ~= c;
			tryMatch(c);
		}).executeInNewThread;
		this.filterFunc = filterFunc;
		startOver;
	}

	void startOver(){

		if(waitLoad)
			waitLoad();

		permanent = [];
		temporary = [];
		scannedDirs = [];

		auto taskExes = task(&loadExecutables, &addTemporary);
		scannedDirs ~= getcwd;
		auto taskFiles = task(&loadFiles, getcwd, &addTemporary, &dirLoaded, 2);
		taskExes.executeInNewThread;
		taskFiles.executeInNewThread;
		waitLoad = {
			while(!taskExes.done || !taskFiles.done)
				Thread.sleep(10.msecs);
		};
		filterThread = new Thread(&filterLoop);
		filterThread.start;
		
		reset;
	}

	void wait(){
	}

	void reset(string filter="", Type mode=Type.none){
		filter = filter.expandTilde;
		scannedDirsTemp = [];
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
			Command[] cpy;
			synchronized(this)
				cpy = permanent ~ temporary ~ output;
			foreach(m; cpy)
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

		void addPermanent(Command p){
			synchronized(this)
				permanent ~= p;
			tryMatch(p);
		}

		void addTemporary(Command p){
			synchronized(this){
				if(p.type == Type.directory){
					if((scannedDirs~scannedDirsTemp).canFind(p.text))
						return;
					else
						scannedDirsTemp ~= p.text;
				}
				temporary ~= p;
			}
			tryMatch(p);
		}

		void tryMatch(Command p){
			if(!filterFunc(p))
				return;
			Match match;
			match.score = p.filterText.cmpFuzzy(filter);
			if(match.score > 0){
				match.score += p.score;
				match.data = p;
				synchronized(this){
					foreach(i, e; matches){
						if(e.score < match.score){
							matches = matches[0..i] ~ match ~ matches[i..$];
							return;
						}
					}
					matches = matches ~ match;
				}
			}
		}

		void filterLoop(){
			filterThread.isDaemon = true;
			try{
				while(true){
					if(narrowQueue.length){
						synchronized(this){
							filter ~= narrowQueue;
							narrowQueue = "";
						}
						intNarrow(filter);
					}else if(restart){
						intReset(filter);
						restart = false;
					}else{
						auto dir = filter.expandTilde.buildNormalizedPath.unixClean;
						if(dir.exists && dir.isDir && !scannedDirs.canFind(dir)){
							task(&loadFiles, dir, &addTemporary, &dirLoaded, 0).executeInNewThread;
						}
						Thread.sleep(15.msecs);
					}
				}
			}catch(Throwable t)
				writeln(t);
		}
	
		bool dirLoaded(string s){
			if((scannedDirs~scannedDirsTemp).canFind(s))
				return true;
			scannedDirs ~= s;
			return false;
		}

	}

}


long cmpFuzzy(string str, string sub){
	long scoreMul = 100;
	long score = scoreMul*10;
	size_t curIdx;
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
	if(!largestScore)
		return 0;
	if(!sub.startsWith(".") && (str.canFind("/.") || str.startsWith(".")))
		largestScore -= 5;
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

