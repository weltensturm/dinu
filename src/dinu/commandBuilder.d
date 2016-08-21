module dinu.commandBuilder;


import dinu;


__gshared:


FuzzyFilter!Command choiceFilter;
Command[] output;

bool isText(char c){
	return !c.isWhite && c != '/';
}

void delChar(ref string text, size_t cursor){
	if(cursor < text.length)
		text = text[0..cursor] ~ text[cursor+1..$];
}

void delBackChar(ref string text, ref size_t cursor){
	if(cursor){
		text = text[0..cursor-1] ~ text[cursor..$];
		cursor--;
	}
}

void deleteWordLeft(ref string text, ref size_t cursor){
	if(!text.length || !cursor)
		return;
	text.delBackChar(cursor);
	if(!cursor)
		return;
	bool mode = text[cursor-1].isText;
	while(cursor && mode == text[cursor-1].isText){
		text = text[0..cursor-1] ~ text[cursor..$];
		cursor--;
	}
}

void deleteWordRight(ref string text, size_t cursor){
	text.delChar(cursor);
	if(cursor >= text.length)
		return;
	bool mode = text[cursor].isText;
	while(cursor < text.length && mode == text[cursor].isText){
		text = text[0..cursor] ~ text[cursor+1..$];
	}
}



class CommandBuilder {

	string[] command;
	size_t editing;
	size_t cursorStart;
	bool shiftDown;
	size_t cursor;

	string filterText;

	Command commandSelected;
	int logIdx=1;
	bool commandHistory;
	string[] scannedDirs;
	Command[] bashCompletions;
	long selected;

	OutputLoader outputLoader;
	ExecutablesLoader execLoader;
	TalkProcessLoader processLoader;
	FilesLoader filesLoader;

	Command[] history;

	this(){

		choiceFilter = new FuzzyFilter!Command((c){
			if(toString.length && toString[0] == '@' && editing == 0){
				return c.type == Type.processInfo;
			}else if(choiceFilter && commandHistory){
				return c.type == Type.history;
			}else if(!bashCompletions.length && toString.length){
				auto filter = [Type.file, Type.directory];
				if(editing == 0)
					filter ~= [Type.script, Type.desktop, Type.special];
				return filter.canFind(c.type);
			}else if(bashCompletions.length){
				return c.type == Type.bashCompletion;
			}else
				return false;
		});

		outputLoader = new OutputLoader;
		outputLoader.each((c){
			if(c.type == Type.history){
				synchronized(this)
					history = c ~ history;
				choiceFilter.add(c);
			}else{
				synchronized(this){
					if(c.score >= 10000*999)
						output = c ~ output;
					else
						output ~= c;
				}
			}
		});

		reset;
		resetChoices;
		resetFilter;
	}

	void cleanup(){
		if(execLoader)
			execLoader.stop;
		if(processLoader)
			processLoader.stop;
		if(filesLoader)
			filesLoader.stop;
	}

	void reset(){
		command = [""];
		editing = 0;
		cursor = 0;
		cursorStart = 0;
		filterText = "";
		commandSelected = null;
		commandHistory = false;
		choiceFilter.reset("");
	}

	void resetFilter(){
		choiceFilter.reset(text);
		selected = -1;
	}

	void resetChoices(){
		bashCompletions = [];
		synchronized(this)
			choiceFilter.set(history.dup);

		if(execLoader)
			execLoader.stop;
		execLoader = new ExecutablesLoader;
		execLoader.each(&choiceFilter.add);

		if(processLoader)
			processLoader.stop;
		processLoader = new TalkProcessLoader;
		processLoader.each(&choiceFilter.add);

		scannedDirs = [];
		if(filesLoader)
			filesLoader.stop;
		filesLoader = new FilesLoader(getcwd, 2, &dirLoaded);
		filesLoader.each((c){
			if(c.type == Type.directory){
				synchronized(this){
					if(scannedDirs.canFind(c.text))
						return;
					else
						scannedDirs ~= c.text;
				}
			}
			choiceFilter.add(c);
		});

		choiceFilter.reset(text);
	}

	void resetState(bool force=false){
		if(!force && editing == 0)
			commandSelected = null;
		if(force || editing != 0 || !text.length){
			commandHistory = false;
			filterText = "";
		}
	}

	void checkNativeCompletions(){
		choiceFilter.remove(bashCompletions);
		resetFilter;
		bashCompletions = [];
		if(command.length > 1){
			task({
				l:foreach(c; loadBashCompletion(toString)){
					foreach(e; bashCompletions)
						if(e.text == c)
							continue l;
					auto completion =  new CommandBashCompletion(c);
					bashCompletions ~= completion;
					choiceFilter.add(completion);
					resetFilter;
				}
			}).executeInNewThread;
		}
	}

	string finishedPart(){
		return reduce!"a ~ ' ' ~ b"("", command[0..editing]);
	}

	string cursorPart(){
		return finishedPart ~ text[0..cursor];
	}

	void clearOutput(){
		std.file.write(options.configPath ~ ".log", "");
		output = [];
		history = [];
	}

	void run(bool r=true){
		if(!command[0].length && !commandHistory)
			return;
		if(!commandSelected){
			auto res = choiceFilter.res;
			if(res.length && selected >= -1)
				commandSelected = res[cast(size_t)(selected<0 ? 0 : selected)].data;
			else
				commandSelected = new CommandFile("http://" ~ command[0]);
		}
		commandSelected.parameter = "";
		if(command.length > 1)
			commandSelected.parameter = command[1..$].reduce!"a ~ ' ' ~ b";
		commandSelected.run;
		if(r){
			deleteLeft;
		}else
			commandSelected.parameter = "";
	}

	// Choice selection

	void select(long selected){
		auto res = choiceFilter.res;
		if(selected == -1){
			if(filterText.length){
				text = filterText[0..$-1];
				cursor = text.length;
				cursorStart = cursor;
				filterText = "";
				if(editing == 0 || commandHistory)
					commandSelected = null;
			}
			this.selected = -1;
		}else if(selected > -1){
			selectChoice(selected);
		}else{
			selectOutput(-selected-2);
		}
	}

	void selectChoice(long selected){
		if(!filterText.length)
			filterText = text ~ ' ';
		auto res = choiceFilter.res;
		if(this.selected < selected){
			if(!res.length && !commandHistory){
				commandHistory = true;
				resetFilter;
				return;
			}
		}
		selected = selected.min(res.length-1);
		auto sel = res[cast(size_t)selected].data;
		if(editing == 0 || commandHistory){
			if(sel.type == Type.history)
				commandSelected = (cast(CommandHistory)sel).command;
			else
				commandSelected = sel;
			if(commandHistory){
				command = [commandSelected.text];
				if(sel.parameter.length)
					command ~= sel.parameter;
				editing = command.length-1;
			}else{
				command[0] = commandSelected.text;
			}
		}else{
			text = sel.text;
		}
		cursor = text.length;
		cursorStart = cursor;
		this.selected = selected;
	}

	void selectOutput(long selected){
		selected = selected.max(0).min(output.length-1);
		if(!filterText.length)
			filterText = text ~ ' ';
		auto c = output[cast(size_t)selected];
		if(c.parameter.length)
			text = c.parameter;
		else
			text = '\'' ~ c.text ~ '\'';
		cursor = text.length;
		cursorStart = cursor;
		this.selected = -selected-2;
	}

	// Text functions

	ref string text(){
		return command[editing];
	}

	void selectAll(){
		cursorStart = 0;
		cursor = text.length;
	}

	void moveLeft(bool word=false){
		if(editing && cursor == 0){
			commandHistory = false;
			editing--;
			cursor = command[editing].length;
			cursorStart = cursor;
			if(editing == 0){
				commandSelected = null;
			}
			resetFilter;
		}else if(!word)
			cursor = cast(size_t)max(0, cast(long)cursor-1);
		if(!shiftDown)
			cursorStart = cursor;
	}

	void moveRight(bool word=false){
		if(cursor == text.length && text.length && editing+1 < command.length){
			resetState;
			if(editing == 0 && !commandSelected)
				select(0);
			editing++;
			cursor = 0;
			cursorStart = 0;
			selected = -1;
			resetFilter;
			commandHistory = false;
		}else if(!word)
			cursor = min(cursor+1, text.length);
		if(!shiftDown)
			cursorStart = cursor;
	}

	// Text altering

	void insert(string s){
		if(cursorStart != cursor)
			deleteSelection;
		if(cursor == text.length && s == " " && (cursor<2 || text[cursor-2] != '\\')){
			if(!commandSelected && editing == 0){
				auto res = choiceFilter.res;
				if(res.length && selected >= -1)
					commandSelected = res[cast(size_t)(selected<0 ? 0 : selected)].data;
				else
					commandSelected = new CommandExec(command[0]);
				text = commandSelected.text;
			}
			resetState(true);
			command ~= "";
			editing++;
			cursor = 0;
			cursorStart = 0;
			resetFilter;
			checkNativeCompletions;
			return;
		}

		if(editing == 0){
			commandSelected = null;
		}
		if(!text.length)
			choiceFilter.reset("");
		text = text[0..cursor] ~ s ~ text[cursor..$];
		cursor += s.length;
		cursorStart = cursor;
		choiceFilter.narrow(s);

		if(filterText.length){
			filterText = "";
			resetFilter;
		}
		select(-1);

		if(s.endsWith("-", "="))
			checkNativeCompletions;

		auto dir = text.expandTilde.buildNormalizedPath.unixClean;
		if(dir.exists && dir.isDir && !scannedDirs.canFind(dir)){
			filesLoader.postLoad(dir, 0);
		}

	}

	void deleteLeft(){
		reset;
		resetChoices;
		select(-1);
		checkNativeCompletions;
	}

	void deleteSelection(){
		text = text[0..min(cursorStart,cursor)] ~ text[max(cursorStart,cursor)..$];
		cursor = cursorStart = min(cursorStart,cursor);
	}

	void delChar(){
		resetState;
		if(cursorStart == cursor)
			text.delChar(cursor);
		else
			deleteSelection;
		resetFilter;
		checkNativeCompletions;
	}

	void delBackChar(){
		resetState;
		if(cursorStart == cursor){
			if(cursor == 0 && command.length && editing > 0){
				command = command[0..editing] ~ command[editing+1..$];
				moveLeft;
				return;
			}
			text.delBackChar(cursor);
		}else{
			deleteSelection;
		}
		cursorStart = cursor;
		resetFilter;
		checkNativeCompletions;
	}

	void deleteWordLeft(){
		resetState;
		if(cursor == 0 && command.length && editing > 0){
			command = command[0..editing] ~ command[editing+1..$];
			moveLeft;
		}
		auto oldLength = text.length;
		text.deleteWordLeft(cursor);
		cursorStart = cursor;
		resetFilter;
		checkNativeCompletions;
	}

	void deleteWordRight(){
		resetState;
		text.deleteWordRight(cursor);
		resetFilter;
		checkNativeCompletions;
	}

	override string toString(){
		if(commandSelected){
			if(command.length > 1)
				return commandSelected.text ~ reduce!"a ~ ' ' ~ b"("", command[1..$]);
			else
				return commandSelected.text;
		}
		if(command.length)
			return command.reduce!"a ~ ' ' ~ b";
		return "";
	}

	protected:

		bool dirLoaded(string s){
			synchronized(this){
				if(scannedDirs.canFind(s))
					return true;
				scannedDirs ~= s;
				return false;
			}
		}


}
