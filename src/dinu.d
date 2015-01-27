module dinu;

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
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef;

__gshared:

int barHeight, windowWidth, windowHeight;
int inputw, promptw;
string dimname = "dimenu";
ColorSet colorNormal;
ColorSet colorSelected;
ColorSet colorDir;
ColorSet colorFile;
ColorSet colorExec;
Atom clip, utf8;
bool running = true;
DrawingContext dc;
Window win;
XIC xic;
Arguments options;

Command command;
ProcessPipes completionProcess;


enum opaque = 0xffffffff;
enum opacity = "_NET_WM_WINDOW_OPACITY";


mixin template cli(T){

	this(string[] args){
		foreach(member; __traits(allMembers, T)) {
			foreach(attr; __traits(getAttributes, mixin(member))){
				foreach(i, arg; args){
					if(arg[0] == '-' && arg == attr){
						static if(is(typeof(mixin(member)) == bool)){
							mixin(member ~ " = ! " ~ member ~ ";");
							continue;
						}else{
							mixin(member ~ " = to!(typeof(" ~ member ~ "))(args[i+1]);");
							continue;
						}
					}
				}
			}
		}
	}

	void usage(){
		writeln("options: ");
		foreach(member; __traits(allMembers, T))
			foreach(attr; __traits(getAttributes, mixin(member)))
				writeln("\t[%s (%s %s)]".format(attr, mixin("typeof(" ~ member ~ ").stringof"), member));
	}

}


struct Arguments {

	@("-v") bool version_;
	@("-l") int lines = 10; // number of lines in vertical list
	@("-fn") string font = "Consolas-10";
	@("-nb") string colorBg = "#222222";
	@("-nf") string colorFg = "#bbbbbb";
	@("-sb") string colorSelectedBg = "#005577";
	@("-sf") string colorSelectedFg = "#eeeeee";
	@("-cd") string colorDir = "#aaffaa";
	@("-cf") string colorFile = "#eeeeee";
	@("-ce") string colorExec = "#aaaaff";
	@("-w") int inputWidth = 300;
	@("-c") string configPath = "~/.dash";

	mixin cli!Arguments;

}


void main(string[] args){
	try {
		options = Arguments(args);
		environment["DE"] = "gnome";
		if(options.configPath.expandTilde.exists)
			chdir(options.configPath.expandTilde.readText.strip);
		dc = new DrawingContext;
		dc.initfont(options.font);
		colorNormal = dc.initcolor(options.colorFg, options.colorBg);
		colorSelected = dc.initcolor(options.colorSelectedFg, options.colorSelectedBg);
		colorDir = dc.initcolor(options.colorDir, options.colorBg);
		colorFile = dc.initcolor(options.colorFile, options.colorBg);
		colorExec = dc.initcolor(options.colorExec, options.colorBg);
		grabKeyboard;
		command = new Command;
		setup;
		run;
		cleanup;
	}catch(Exception e){
		writeln(e);
		running = false;
	}
}


struct CompletionEntry {

	string text;
	int type;

	enum:int {
		executable,
		directory,
		file
	}

}


CompletionEntry[] entries(string dir){
	CompletionEntry[] completions;
	dir = dir.expandTilde;
	string cwd = getcwd;
	foreach(entry; dirEntries(dir, SpanMode.shallow)){
		bool d = entry.isDir;
		string prefix = dir.chompPrefix(cwd).chomp("/");
		completions ~= CompletionEntry(
			prefix ~ (prefix.length ? "/" : "") ~ entry.baseName,
			d ? CompletionEntry.directory : CompletionEntry.file
		);
	}
	return completions;
}



class Parameter {

	string text;
	int cursor;
	string filterText;
	int selected = -1;
	CompletionEntry[] completions;
	CompletionEntry[] matches;

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
		drawmenu;
	}

	void filter(){
		matches = completions.filter(selected>-1 ? filterText : text);
	}

	void update(){
		filterText = "";
		selected = -1;
		matches = [];
		filter;
		drawmenu;
	}

	void insert(string s){
		text = text[0..cursor] ~ s ~ text[cursor..$];
		cursor += s.length;
		update;
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


}


class ParameterArgument: Parameter {

	this(){
		completions = getcwd.entries;
	}

	override void update(){
		super.update;
		completions = getcwd.entries;
		auto dir = text.expandTilde;
		if(dir.exists && dir.isDir)
			completions ~= dir.entries;//CompletionEntry(dir.chomp("/") ~ '/' ~ entry.baseName, entry.isDir ? CompletionEntry.directory : CompletionEntry.file);
	}


}


class ParameterLauncher: Parameter {
	
	this(){
		task(&readCommands).executeInNewThread;
	}

	override void update(){
		super.update;
		auto dir = text.expandTilde;
		if(dir.exists && dir.isDir)
			completions ~= dir.entries;//CompletionEntry(dir.chomp("/") ~ '/' ~ entry.baseName, entry.isDir ? CompletionEntry.directory : CompletionEntry.file);
	}

	void readCommands(){
		completions = getcwd.entries;
		auto p = pipeShell("compgen -ack -A function", Redirect.stdout);
		p.pid.wait;
		foreach(line; p.stdout.byLine){
			completions ~= CompletionEntry(line.to!string, CompletionEntry.executable);
		}
	}
}


class Command {

	Parameter[] params;
	Parameter currentParam;

	alias currentParam this;

	this(){
		reset;
	}

	void reset(){
		params = [];
		params ~= new ParameterLauncher;
		currentParam = params[0];
	}

	void next(){
		params ~= new ParameterArgument;
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
		if(toString.expandTilde.exists)
			task(&spawnCommand, "xdg-open " ~ toString).executeInNewThread;
		else
			task(&spawnCommand, toString).executeInNewThread;
		if(toString.startsWith("cd")){
			string cwd = toString[3..$].expandTilde;
			chdir(cwd);
			std.file.write(options.configPath.expandTilde, getcwd);
		}else
			running = false;
		reset;

	}

	override string toString(){
		string text;
		foreach(s; params)
			text ~= s.text;
		return text;
	}

}


void spawnCommand(string command){
	auto pipes = pipeShell(command);
	task({
		foreach(line; pipes.stdout.byLine)
			spawnShell(`notify-send "%s"`.format(line));
	}).executeInNewThread;
	foreach(line; pipes.stderr.byLine)
		spawnShell(`notify-send "%s" -u critical`.format(line));
	pipes.pid.wait;
}


char[][] splitParam(char[] line){
	return line.split("  ");
}

CompletionEntry[] filter(CompletionEntry[] what, string with_){
	struct Result {
		int score;
		CompletionEntry content;
	}
	Result[] res;
	iter:foreach(entry; what){
		Result possible;
		int current;
		int scoreMul = 10;
		foreach(c; entry.text)
			if(current < with_.length && with_[current].toLower == c.toLower){
				scoreMul *= (with_[current] != c ? 2 : 4);
				current++;
				possible.score += scoreMul;
			}else
				scoreMul = 10;
		//if(with_.startsWith(".") != entry.text.startsWith("."))
		//	possible.score -= 50;
		if(current == with_.length){
			possible.content = entry;
			size_t distance = entry.text.levenshteinDistance(with_);
			possible.score -= distance;
			if(entry.type == CompletionEntry.executable && distance){
				possible.score /= 10;
				possible.score -= 10;
			}
			res ~= possible;
		}
	}
	//res.sort!((a,b) => (a.score-b.score)-a.content.cmp(b.content)>0);
	res.sort!((a,b) => a.score-b.score>0);
	CompletionEntry[] ret;
	foreach(r; res)
		ret ~= r.content;
	return ret;
}



void setup(){
	int x, y;
	int screen = DefaultScreen(dc.dpy);
	Screen *defScreen = DefaultScreenOfDisplay(dc.dpy);
	int dimx, dimy, dimw, dimh;
	Window root = RootWindow(dc.dpy, screen);
	XSetWindowAttributes swa;
	XIM xim;
	clip = XInternAtom(dc.dpy, "CLIPBOARD",	false);
	utf8 = XInternAtom(dc.dpy, "UTF8_STRING", false);
	/* calculate menu geometry */
	barHeight = cast(int)(dc.font.height + 4);
	//lines = max(lines, 0);
	windowHeight = barHeight*10;
	//windowHeight = (lines + 1) * barHeight;
	x = 0;
	y = 0;
	windowWidth = DisplayWidth(dc.dpy, screen);
	//windowHeight = DisplayHeight(dc.dpy, screen);
	dimx = 0;
	dimy = 0;
	dimw = WidthOfScreen(defScreen); 
	dimh = HeightOfScreen(defScreen);
	inputw = draw.min(inputw, windowWidth/3);
	swa.override_redirect = true;
	swa.background_pixel = colorNormal.background;
	swa.event_mask = ExposureMask | KeyPressMask | VisibilityChangeMask;
	win = XCreateWindow(
		dc.dpy, root, x, y, windowWidth, windowHeight, 0,
		DefaultDepth(dc.dpy, screen), CopyFromParent,
		DefaultVisual(dc.dpy, screen),
		CWOverrideRedirect | CWBackPixel | CWEventMask, &swa
	);	XClassHint hint;
	hint.res_name = cast(char*)"dash";
	hint.res_class = cast(char*)"Dash";
	XSetClassHint(dc.dpy, win, &hint);
	xim = XOpenIM(dc.dpy, null, null, null);
	xic = XCreateIC(
		xim, XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
		XNClientWindow, win, XNFocusWindow, win, null
	);
	XMapRaised(dc.dpy, win);
	dc.resizedc(windowWidth, windowHeight);
	drawmenu;
}


void cleanup(){
	XDestroyWindow(dc.dpy, win);
	XUngrabKeyboard(dc.dpy, CurrentTime);
	dc.destroy;
}


void drawmenu(){
	command.filter;
	dc.drawrect(0, 0, windowWidth, windowHeight, true, colorNormal.background);
	int inputWidth = dc.textWidth(command.toString);//draw.max(options.inputWidth, dc.textWidth(text));
	int paddingHoriz = barHeight/4;
	int cwdWidth = dc.textWidth(getcwd);

	// cwd
	dc.drawrect(0, 0, cwdWidth+paddingHoriz*2, barHeight, true, colorSelected.background);
	dc.drawtext([paddingHoriz, dc.font.height-1], getcwd, colorSelected);

	// input
	int[2] textPos = [
		cwdWidth+paddingHoriz*3,
		dc.font.height-1
	];
	dc.drawtext(textPos, command.toString, colorNormal);

	int offset = dc.textWidth(command.finishedPart);
	// cursor
	int curpos = textPos[0]+offset + dc.textWidth(command.toString[0..command.cursor]);
	dc.drawrect(curpos, 3, 1, dc.font.height-3, true, colorNormal.foreground);

	// matches
	foreach(i, match; command.matches[0..draw.min(9UL, $)]){
		int[2] pos = [textPos[0]+offset, cast(int)(i*barHeight+barHeight+dc.font.height-1)];
		if(i == command.selected)
			dc.drawrect(cwdWidth+paddingHoriz*2, cast(int)(i*barHeight+barHeight), windowWidth-cwdWidth-paddingHoriz*2, barHeight, true, colorSelected.background);
		auto color =
			match.type == CompletionEntry.executable ? colorExec
			: match.type == CompletionEntry.directory ? colorDir
			: match.type == CompletionEntry.file ? colorFile
			: colorNormal;
		dc.drawtext(pos, match.text, color);
	}

	dc.mapdc(win, windowWidth, windowHeight);
}

void grabKeyboard(){
	foreach(i; 0..100){
		if(XGrabKeyboard(dc.dpy, DefaultRootWindow(dc.dpy), true, GrabModeAsync, GrabModeAsync, CurrentTime) == GrabSuccess)
			return;
		Thread.sleep(dur!"msecs"(10));
	}
	writeln("cannot grab keyboard");
}


void keypress(XKeyEvent* ev){
	char[5] buf;
	KeySym key;
	Status status;
	auto length = Xutf8LookupString(xic, ev, buf.ptr, cast(int)buf.length, &key, &status);
	if(ev.state & ControlMask)
		switch(key){
			case XK_q:
				key = XK_Escape;
				break;
			case XK_u:
				command.deleteLeft;
				drawmenu;
				return;
			case XK_BackSpace:
				command.deleteWordLeft;
				drawmenu;
				return;
			case XK_Delete:
				command.deleteWordRight;
				return;
			case XK_V:
			case XK_v:
				XConvertSelection(dc.dpy, clip, utf8, utf8, win, CurrentTime);
				return;
			default:
				return;
		}
	switch(key){
		case XK_Escape:
			running = false;
			return;
		case XK_Delete:
			command.delChar;
			drawmenu;
			return;				
		case XK_BackSpace:
			command.delBackChar;
			drawmenu;
			return;
		case XK_Left:
			if(command.cursor > 0)
				command.cursor--;
			drawmenu;
			return;
		case XK_Right:
			if(command.cursor < command.text.length)
				command.cursor++;
			drawmenu;
			return;
		case XK_Tab:
			command.selectNext;
			return;
		case XK_Return:
		case XK_KP_Enter:
			command.run;
			drawmenu;
			return;
		default:
			break;
	}
	if(dc.actualWidth(buf[0..length].to!string) > 0){
		string s = buf[0..length].to!string;
		command.insert(s);
		if(s == " ")
			command.next;
		drawmenu;
	}
}

void paste(){
	char* p;
	int actualFormat;
	ulong count;
	Atom actualType;
	XGetWindowProperty(
		dc.dpy, win, utf8, 0, 1024, false, utf8,
		&actualType, &actualFormat, &count, &count, cast(ubyte**)&p
	);
	writeln(p);
	command.insert(p.to!string);
	XFree(p);
	drawmenu;
}


void run(){
	XEvent ev;
	while(running && !XNextEvent(dc.dpy, &ev)){
		if(XFilterEvent(&ev, win))
			continue;
		switch(ev.type){
		case Expose:
			if(ev.xexpose.count == 0)
				dc.mapdc(win, windowWidth, windowHeight);
			break;
		case KeyPress:
			keypress(&ev.xkey);
			break;
		case SelectionNotify:
			if(ev.xselection.property == utf8)
				paste();
			break;
		case VisibilityNotify:
			if(ev.xvisibility.state != VisibilityUnobscured)
				XRaiseWindow(dc.dpy, win);
			break;
		default: break;
		}
	}
}
