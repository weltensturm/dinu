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
	dinu.launcher,
	dinu.xclient,
	dinu.resultWindow,
	cli;


__gshared:


Options options;

Launcher launcher;

bool runProgram = true;



struct Options {

	@("-x") int x;
	@("-y") int y;
	@("-w") int w;
	@("-h") int h;
	@("-l") int lines = 15;
	@("-fn") string font = "Monospace-10";
	@("-c") string configPath = "~/.dinu/default";
	@("-s") int screen;

	@("-cb") string colorBg = "#252525";
	@("-ci") string colorInput = "#ffffff";
	@("-cib") string colorInputBg = "#555555";
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

	mixin cli!Options;

}


void main(string[] args){
	try {
		options = Options(args);
		options.configPath = options.configPath.expandTilde;
		if(!options.configPath.dirName.exists)
			mkdirRecurse(options.configPath.dirName);
		if(options.configPath.exists)
			chdir(options.configPath.expandTilde.readText.strip);
		windowLoop;
	}catch(Exception e){
		writeln(e);
	}
}

void windowLoop(){
	launcher = new Launcher;

	auto windowMain = new XClient;
	windowMain.draw;

	auto windowResults = new ResultWindow;
	windowResults.draw;

	scope(exit){
		windowMain.destroy;
		windowResults.destroy;
		runProgram = false;
	}

	long last = Clock.currSystemTick.msecs;
	while(windowMain.active || windowResults.active){
		windowMain.handleEvents;
		windowMain.draw;
		windowResults.update(windowMain);
		windowResults.handleEvents;
		windowResults.draw;
		auto curr = Clock.currSystemTick.msecs;
		last = curr;
		Thread.sleep((15 - max(0, min(15, curr-last))).msecs);
	}
}



