module dinu.dinu;


import
	std.path,
	std.math,
	std.process,
	std.file,
	std.string,
	std.stdio,
	std.conv,
	std.datetime,
	std.algorithm,
	std.parallelism,
	core.thread,
	draw,
	cli,
	dinu.launcher,
	dinu.command,
	dinu.xclient,
	desktop,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef;


__gshared:


Arguments options;


struct Arguments {

	@("-x") int x;
	@("-y") int y;
	@("-w") int w;
	@("-h") int h;
	@("-l") int lines = 15; // number of lines in vertical list
	@("-fn") string font = "Monospace-10";
	@("-n") bool noNotify;
	@("-nb") string colorBg = "#111111";
	@("-nf") string colorText = "#eeeeee";
	@("-co") string colorOutput = "#cccccc";
	@("-co") string colorOutputBg = "#222222";
	@("-ce") string colorError = "#ff7777";
	@("-sb") string colorSelected = "#005577";
	@("-ch") string colorHint = "#777777";
	@("-cd") string colorDir = "#aaffaa";
	@("-cf") string colorFile = "#eeeeee";
	@("-ce") string colorExec = "#aaaaff";
	@("-cd") string colorDesktop = "#acccff";
	@("-ci") string colorInputBg = "#333333";
	@("-c") string configPath = "~/.dinu/default";

	mixin cli!Arguments;

}

bool createWin = true;
bool runProgram = true;


void main(string[] args){
	try {

		XInitThreads();
		options = Arguments(args);
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
	dc = new DrawingContext;
	dc.initfont(options.font);
	colorBg = dc.fontColor(options.colorBg);
	colorSelected = dc.color(options.colorSelected);
	colorText = dc.fontColor(options.colorText);
	colorOutput = dc.fontColor(options.colorOutput);
	colorOutputBg = dc.fontColor(options.colorOutputBg);
	colorError = dc.fontColor(options.colorError);
	colorDir = dc.fontColor(options.colorDir);
	colorFile = dc.fontColor(options.colorFile);
	colorExec = dc.fontColor(options.colorExec);
	colorHint = dc.fontColor(options.colorHint);
	colorDesktop = dc.fontColor(options.colorDesktop);
	colorInputBg = dc.fontColor(options.colorInputBg);

	launcher = new Launcher;

	client = new XClient;
	client.draw;
	scope(exit)
		client.close;
	client.grabKeyboard;
	long last = Clock.currSystemTick.msecs;
	while(client.open){
		client.handleEvents;
		client.draw;
		auto curr = Clock.currSystemTick.msecs;
		last = curr;
		Thread.sleep((15 - max(0, min(15, curr-last))).msecs);
	}
	dc.destroy;
}



