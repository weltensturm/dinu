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
	dinu.xapp,
	dinu.window,
	dinu.resultWindow,
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
	@("-l") int lines = 15;
	@("-fn") string font = "Monospace-10";

	// dark theme
	@("-nb") string colorBg = "#252525";
	@("-nf") string colorText = "#ffffff";
	@("-co") string colorOutput = "#eeeeee";
	@("-co") string colorOutputBg = "#444444";
	@("-ce") string colorError = "#ff7777";
	@("-sb") string colorSelected = "#005577";
	@("-ch") string colorHint = "#999999";
	@("-cd") string colorDir = "#bbeebb";
	@("-cf") string colorFile = "#eeeeee";
	@("-ce") string colorExec = "#bbbbff";
	@("-cd") string colorDesktop = "#bdddff";
	@("-ci") string colorInputBg = "#555555";

	/+
	// light theme
	@("-nb") string colorBg = "#dddddd";
	@("-nf") string colorText = "#111111";
	@("-co") string colorOutput = "#333333";
	@("-co") string colorOutputBg = "#bbbbbb";
	@("-ce") string colorError = "#aa0000";
	@("-sb") string colorSelected = "#00aaff";
	@("-ch") string colorHint = "#555555";
	@("-cd") string colorDir = "#007700";
	@("-cf") string colorFile = "#333333";
	@("-ce") string colorExec = "#0000ff";
	@("-cd") string colorDesktop = "#3333ff";
	@("-ci") string colorInputBg = "#bbbbbb";
	+/

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

	auto window = new ResultWindow(new XApp, [client.size.w/4, client.size.h+options.y], [500, 500], options);
	window.draw;

	scope(exit){
		client.close;
		window.close;
		window.handleEvents;
	}
	client.grabKeyboard;
	long last = Clock.currSystemTick.msecs;
	while(client.open && window.open){
		client.handleEvents;
		client.draw;
		window.handleEvents;
		window.draw;
		//window.handleEvents;
		//window.draw;
		auto curr = Clock.currSystemTick.msecs;
		last = curr;
		Thread.sleep((15 - max(0, min(15, curr-last))).msecs);
	}
	dc.destroy;
}



