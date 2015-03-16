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
	int logIdx=1;

	alias currentParam this;

	this(){
		choiceFilter = new ChoiceFilter;
		reset;
	}

	void reset(Type mode = Type.none){
		//choiceFilter = new ChoiceFilter;
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
		choiceFilter.output = [];
	}

	void run(bool res=true){
		if(!command.command){
			command.finishPart;
			if(command.selected<0){
				client.close;
				return;
			}
		}
		/+
		if(toString.startsWith("cd ")){
			string cwd = toString[3..$].expandTilde.unixClean;
			chdir(cwd);
			command.command.run(reduce!"a ~ b.text"("", params));
			std.file.write(options.configPath.expandTilde, getcwd);
			reset;
			choiceFilter.startOver;
			return;
		}else if(toString.strip == "clear"){
			reset;
			choiceFilter.startOver;
			return;
		}else +/
		if(command.command){
			command.command.run(reduce!"a ~ b.text"("", params));
			if(res)
				choiceFilter.startOver;
		}
		if(res)
			reset;
	}

	/+
	CommandHistory addHistory(Command command, string params){
		synchronized(this){
			auto history = new CommandHistory(command, params, logIdx++);
			choiceFilter.addPermanent(history);
			return history;
		}
	}

	void addOutput(Command command, string output, bool err){
		synchronized(this){
			choiceFilter.addPermanent(new CommandOutput(command.text, output, logIdx++, err));
		}
	}
	+/

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
		if(selected >= res.length)
			selected = -1;
		else if(selected < -1)
			selected = res.length-1L;
		if(selected != -1){
			if(!filterText.length)
				filterText = text;
			text = res[cast(size_t)selected].data.text;
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

	//override void update(){
		//setSelected(0);
	//}

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

	/+
	override protected void setSelected(long selected){
		auto res = choiceFilter.res;
		long min = text.length ? 0 : -1;
		if(selected >= cast(long)res.length)
			selected = min;
		else if(selected < min)
			selected = res.length-1L;
		this.selected = selected;
	}
	+/


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

		Type typeFilter;

		string[] scannedDirs;

	}

	bool commandHistory;

	this(){
		task(&loadOutput, (Command c){
			synchronized(this)
				output ~= c;
			tryMatch(c);
		}).executeInNewThread;
		startOver;
	}

	void startOver(){

		if(waitLoad)
			waitLoad();

		permanent = [];
		temporary = [];

		auto taskExes = task(&loadExecutables, &addTemporary);
		scannedDirs ~= getcwd;
		auto taskFiles = task(&loadFiles, getcwd, &addTemporary, false);
		//auto taskOutput = task(&loadOutput, &addPermanent);
		taskExes.executeInNewThread;
		taskFiles.executeInNewThread;
		//taskOutput.executeInNewThread;
		waitLoad = {
			while(!taskExes.done || !taskFiles.done)
				Thread.sleep(10.msecs);
		};
		filterThread = new Thread(&filterLoop);
		filterThread.start;
		
		reset;
	}

	void wait(){
		/+
		writeln("waiting");
		waitLoad();
		while(!idle)
			Thread.sleep(10.msecs);
		idle = false;
		writeln("done");
		idle = true;
		+/
	}

	void reset(string filter="", Type mode=Type.none){
		filter = filter.expandTilde;
		if(mode){
			typeFilter = mode;
		}else if(commandHistory){
			typeFilter = Type.history;
		}else if(!filter.length && (!launcher || !launcher.params.length)){
			typeFilter = Type.output | Type.history;
		}else{
			typeFilter = Type.file | Type.directory;
			if(launcher && !launcher.params.length)
				typeFilter = typeFilter | Type.script | Type.desktop | Type.special;
		}
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
			synchronized(this)
				temporary ~= p;
			tryMatch(p);
		}

		void tryMatch(Command p){
			if(typeFilter && !(p.type & typeFilter))
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
							//client.sendUpdate;
							return;
						}
					}
					matches = matches ~ match;
				}
				//client.sendUpdate;
			}
		}

		void filterLoop(){
			filterThread.isDaemon = true;
			try{
				while(true){
					if(narrowQueue.length){
						synchronized(this){
							//writeln("narrow queue ", narrowQueue, " ", typeFilter);
							filter ~= narrowQueue;
							narrowQueue = "";
						}
						intNarrow(filter);
						//client.sendUpdate;
					}else if(restart){
						//writeln("restart ", filter, " ", typeFilter);
						intReset(filter);
						restart = false;
						//client.sendUpdate;
					}else{
						auto dir = filter.expandTilde.buildNormalizedPath.unixClean;
						if(dir.exists && dir.isDir && !scannedDirs.canFind(dir)){
							scannedDirs ~= dir;
							task(&loadFiles, dir, &addTemporary, true).executeInNewThread;
						}
						Thread.sleep(15.msecs);
						//client.sendUpdate;
					}
				}
			}catch(Throwable t)
				writeln(t);
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
	//score -= phoneticalScore(str);
	//score -= abs(sub.icmp(str));
	//writeln(total, ' ', str, ' ', scores);
	if(!largestScore)
		return 0;
	//largestScore -= sub.levenshteinDistance(str)*4;
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

