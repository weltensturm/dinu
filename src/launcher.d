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
	dinu.filter,
	dinu.command;


__gshared:


FuzzyFilter!Command choiceFilter;
FuzzyFilter!Command output;


class Launcher {

	CommandPicker command;
	Picker[] params;
	Picker currentParam;
	int logIdx=1;
	bool commandHistory;
	string[] scannedDirs;
	string[] scannedDirsTemp;
	string[] bashCompletions;

	alias currentParam this;

	this(){

		choiceFilter = new FuzzyFilter!Command((c){
			if(choiceFilter && commandHistory){
				return c.type == Type.history;
			}else if(!bashCompletions.length && toString.length){
				auto filter = [Type.file, Type.directory];
				if(launcher && !launcher.params.length)
					filter ~= [Type.script, Type.desktop, Type.special];
				return filter.canFind(c.type);
			}else if(bashCompletions.length){
				return c.type == Type.bashCompletion;
			}else
				return false;
		});

		output = new FuzzyFilter!Command((c){
			return c.type == Type.output || c.type == Type.history;
		});

		task(&loadOutput, delegate(Command c){
			choiceFilter.addChoice(c);
			output.addChoice(c);
		}).executeInNewThread;

		reset;
		filterStart;
	}

	void filterStart(){

		scannedDirs = [];
		scannedDirsTemp = [];

		auto taskExes = task(&loadExecutables, &choiceFilter.addChoice);
		scannedDirs ~= getcwd;
		auto taskFiles = task(
			&loadFiles,
			getcwd,
			(Command p){
				if(p.type == Type.directory){
					if((scannedDirs~scannedDirsTemp).canFind(p.text))
						return;
					else
						scannedDirsTemp ~= p.text;
				}
				choiceFilter.addChoice(p);
			},
			&dirLoaded,
			2
		);
		taskExes.executeInNewThread;
		taskFiles.executeInNewThread;
		choiceFilter.start({
			while(!taskExes.done || !taskFiles.done)
				Thread.sleep(10.msecs);
		});
	}

	void reset(){
		params = [];
		command = new CommandPicker;
		currentParam = command;
		commandHistory = false;
		bashCompletions = [];
		choiceFilter.reset("");
	}

	void toggleCommandHistory(){
		commandHistory = true;
		choiceFilter.reset;
	}

	void next(){
		params ~= new Picker;
		commandHistory = false;
		choiceFilter.reset;
		currentParam = params[$-1];
		currentParam.update;
	}

	string finishedPart(){
		if(params.length)
			return reduce!"a ~ b.text"(command.command.text ~ ' ', params[0..$-1]);
		return "";
	}

	void clearOutput(){
		std.file.write(options.configPath ~ ".log", "");
		// TODO: clear data in filter
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
			if(res){
				filterStart;
			}
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

	protected:

		bool dirLoaded(string s){
			if((scannedDirs~scannedDirsTemp).canFind(s))
				return true;
			scannedDirs ~= s;
			return false;
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

	protected void setSelected(long selected, bool nice=false){
		auto res = choiceFilter.res;
		auto output = output.res;
		selected = selected.min(cast(long)res.length-1).max(-1-cast(long)output.length);
		if(selected != -1){
			if(this.selected == -1)
				filterText = text;
			if(selected > -1)
				text = res[cast(size_t)selected].data.text;
			else
				text = output[cast(size_t)(-selected-2)].data.text;
		}else if(this.selected != -1 && !nice){
			text = filterText;
			filterText = "";
		}
		cursor = text.length;
		this.selected = selected;
	}

	void moveLeft(bool word){
		if(!word)
			cursor = max(0, cast(long)cursor-1);
	}

	void moveRight(bool word){
		if(!word)
			cursor = min(cursor+1, text.length);
	}

	void selectNext(){
		auto old = selected;
		setSelected(selected+1);
		cursor = text.length;
		if(old == -1 && !launcher.commandHistory && !launcher.text.length){
			launcher.commandHistory = true;
			choiceFilter.reset;
		}
	}

	void selectPrev(){
		setSelected(selected-1);
		cursor = text.length;
	}

	void update(){
		filterText = "";
		setSelected(-1, true);

		if(launcher.toString.length && launcher.toString[$-1] == ' '){
			//choiceFilter.remove(a => a.type == Type.bashCompletion);
			launcher.bashCompletions = [];
			task(&loadParams, launcher.toString, delegate(Command c){
					//choiceFilter.addChoice(c);
					launcher.bashCompletions ~= c.text;
					//choiceFilter.reset;
			}).executeInNewThread;
		}

		/+
		auto dir = text.expandTilde.buildNormalizedPath.unixClean;
		if(dir.exists && dir.isDir && !launcher.scannedDirs.canFind(dir)){
			task(&loadFiles, dir, &choiceFilter.addChoice, &launcher.dirLoaded, 0).executeInNewThread;
		}
		+/
	}

	void finishPart(){
		launcher.next;
	}

	void onDel(){
		update;
		if(!text.length)
			launcher.commandHistory = false;
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

	protected override void setSelected(long s, bool n=false){
		super.setSelected(s, n);
		if(selected < -1){
			auto p = new Picker;
			p.text = output.res[-selected-2].data.parameter;
			if(!p.text.length)
				return;
			launcher.text ~= ' ' ~ p.text;
			writeln(p.text);
		}
	}

	override void onDel(){
		super.onDel;
		if(!text.length)
			setSelected(-1);
	}

	override protected void finishPart(){
		if(!text.length && selected<0)
			return;
		if(selected >= -1){
			if(choiceFilter.res.length){
				selected = (selected<0 ? (selected<-1 ? -selected+2 : 0) : selected);
				command = choiceFilter.res[cast(size_t)selected].data;
			}
		}else if(selected < -1){
			if(output.res.length){
				selected = -selected-2;
				command = output.res[cast(size_t)selected].data;
			}
		}
		if(!command)
			command = new CommandExec(text);
		text = command.text ~ ' ';
		writeln('"', text, '"');
		cursor = text.length;
		launcher.next;
	}

}

