module dinu.dinu;


import
	core.thread,
	std.algorithm,
	std.conv,
	std.stdio,
	std.string,
	std.path,
	std.file,
	std.datetime,
	x11.Xlib,
	dinu.commandBuilder,
	dinu.xclient,
	dinu.resultWindow,
	cli;


__gshared:


Options options;

CommandBuilder commandBuilder;

bool runProgram = true;

void delegate() close;


struct Options {

	@("-h") bool help;

	@("-x") int x;
	@("-y") int y;
	@("-w") int w;
	@("-l") int lines = 15;
	@("-fn") string font = "Monospace-10";
	@("-c") string configPath = "~/.dinu/default";
	@("-s") int screen;

	@("-cb") string colorBg = "#252525";
	@("-ci") string colorInput = "#ffffff";
	@("-cib") string colorInputBg = "#454545";
	@("-co") string colorOutput = "#eeeeee";
	@("-cob") string colorOutputBg = "#111111";
	@("-ce") string colorError = "#ff7777";
	@("-cs") string colorSelected = "#005577";
	@("-ch") string colorHint = "#999999";
	@("-chb") string colorHintBg = "#444444";
	@("-cd") string colorDir = "#bbeebb";
	@("-cf") string colorFile = "#eeeeee";
	@("-ce") string colorExec = "#bbbbff";
	@("-cde") string colorDesktop = "#bdddff";

}


void main(string[] args){
	try {
		options.fill(args);
		if(options.help){
			options.usage;
			return;
		}
		options.configPath = options.configPath.expandTilde;
		if(!options.configPath.dirName.exists)
			mkdirRecurse(options.configPath.dirName);
		if(options.configPath.exists)
			chdir(options.configPath.expandTilde.readText.strip);
		windowLoop;
	}catch(Throwable t){
		writeln(t);
	}
}

void windowLoop(){
	commandBuilder = new CommandBuilder;

	auto windowMain = new XClient;
	windowMain.draw;

	auto windowResults = new ResultWindow;
	windowResults.draw;

	windowMain.resultWindow = windowResults;

	close = {
		windowMain.destroy;
		windowResults.destroy;
		runProgram = false;
	};

	scope(exit)
		close();

	long last = Clock.currSystemTick.msecs;
	while(windowMain.active){
		windowMain.handleEvents;
		windowMain.draw;
		windowMain.update;
		if(runProgram){
			windowResults.handleEvents;
			windowResults.update(windowMain);
			windowResults.draw;
		}
		auto curr = Clock.currSystemTick.msecs;
		last = curr;
		Thread.sleep((15 - max(0, min(15, curr-last))).msecs);
	}
}



