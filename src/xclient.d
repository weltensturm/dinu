module dinu.xclient;

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
	core.thread,
	draw,
	cli,
	dinu.launcher,
	desktop,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef;

__gshared:

int barHeight;

DrawingContext dc;
Color colorBg;
Color colorSelected;
FontColor colorText;
FontColor colorDir;
FontColor colorFile;
FontColor colorExec;
FontColor colorHint;
FontColor colorDesktop;

Arguments options;

Launcher launcher;

XClient client;


struct Arguments {

	@("-l") int lines = 10; // number of lines in vertical list
	@("-fn") string font = "Consolas-13";
	@("-n") bool noNotify;
	@("-nb") string colorBg = "#222222";
	@("-nf") string colorText = "#eeeeee";
	@("-sb") string colorSelected = "#444444";
	@("-ch") string colorHint = "#777777";
	@("-cd") string colorDir = "#aaffaa";
	@("-cf") string colorFile = "#eeeeee";
	@("-ce") string colorExec = "#aaaaff";
	@("-cd") string colorDesktop = "#acacff";
	@("-c") string configPath = "~/.dinu/default";

	mixin cli!Arguments;

}


void main(string[] args){
	try {
		XInitThreads();
		options = Arguments(args);
		environment["DE"] = "gnome";
		if(options.configPath.expandTilde.exists)
			chdir(options.configPath.expandTilde.readText.strip);

		dc = new DrawingContext;
		dc.initfont(options.font);
		colorBg = dc.color(options.colorBg);
		colorSelected = dc.color(options.colorSelected);
		colorText = dc.fontColor(options.colorText);
		colorDir = dc.fontColor(options.colorDir);
		colorFile = dc.fontColor(options.colorFile);
		colorExec = dc.fontColor(options.colorExec);
		colorHint = dc.fontColor(options.colorHint);
		colorDesktop = dc.fontColor(options.colorDesktop);

		//spawnShell("notify-send " ~ options.configPath);

		client = new XClient;
		launcher = new Launcher;
		client.draw;
		scope(exit)
			client.destroy;
		client.grabKeyboard;
		client.handleEvents;
	}catch(Exception e){
		writeln(e);
	}
}

int em(double mod){
	return cast(int)(dc.font.height*1.3*mod);
}

class XClient {

	bool running = true;
	XIC xic;
	Atom clip;
	Atom utf8;
	Window windowHandle;
	int[2] size;
	

	this(){
		int screen = DefaultScreen(dc.dpy);
		int dimx, dimy, dimw, dimh;
		Window root = RootWindow(dc.dpy, screen);
		XSetWindowAttributes swa;
		XIM xim;
		clip = XInternAtom(dc.dpy, "CLIPBOARD",	false);
		utf8 = XInternAtom(dc.dpy, "UTF8_STRING", false);
		barHeight = 1.em;
		size[0] = DisplayWidth(dc.dpy, screen);
		size[1] = barHeight*(options.lines+1);
		swa.override_redirect = true;
		swa.background_pixel = colorBg;
		swa.event_mask = ExposureMask | KeyPressMask | VisibilityChangeMask;
		windowHandle = XCreateWindow(
			dc.dpy, root, 0, 0, size[0], size[1], 0,
			DefaultDepth(dc.dpy, screen), CopyFromParent,
			DefaultVisual(dc.dpy, screen),
			CWOverrideRedirect | CWBackPixel | CWEventMask, &swa
		);
		XClassHint hint;
		hint.res_name = cast(char*)"dash";
		hint.res_class = cast(char*)"Dash";
		XSetClassHint(dc.dpy, windowHandle, &hint);
		xim = XOpenIM(dc.dpy, null, null, null);
		xic = XCreateIC(
			xim, XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
			XNClientWindow, windowHandle, XNFocusWindow, windowHandle, null
		);
		XMapRaised(dc.dpy, windowHandle);
		dc.resizedc(size[0], size[1]);
	}

	void destroy(){
		running = false;
		XDestroyWindow(dc.dpy, windowHandle);
		XUngrabKeyboard(dc.dpy, CurrentTime);
		dc.destroy;
	}

	protected void draw(){
		
		assert(thread_isMainThread);

		auto matches = choiceFilter.res;

		dc.rect([0,0], size, colorBg);
		int inputWidth = dc.textWidth(launcher.toString);//draw.max(options.inputWidth, dc.textWidth(text));
		int paddingHoriz = 0.2.em;
		int cwdWidth = dc.textWidth(getcwd);

		// cwd
		dc.rect([0,0], [cwdWidth+paddingHoriz*2, barHeight], colorSelected);
		dc.text([paddingHoriz, dc.font.height-1], getcwd, colorText);

		// input
		int[2] textPos = [
			cwdWidth+paddingHoriz*3,
			dc.font.height-1
		];
		dc.text(textPos, launcher.toString, colorText);

		int offset = dc.textWidth(launcher.finishedPart);
		// cursor
		int curpos = textPos[0]+offset + dc.textWidth(launcher.toString[0..launcher.cursor]);
		dc.rect([curpos, 0.1.em], [1, 0.9.em], colorText.id);

		// matches
		size_t section = cast(size_t)(launcher.selected/options.lines);
		assert(section <= matches.length/options.lines, "%s".format(section));
		size_t start = section*options.lines;
		foreach(i, match; matches[start..min($, start+options.lines)]){
			int[2] pos = [textPos[0]+offset, cast(int)(i*barHeight+barHeight+dc.font.height-1)];
			//dc.text([0.1.em, pos[1]], match.score.to!string, colorHint);
			if(start+i == max(0-cast(long)launcher.params.length, launcher.selected))
				dc.rect([cwdWidth+paddingHoriz*2, cast(int)(i*barHeight+barHeight)], [size[0]-cwdWidth-paddingHoriz*2, barHeight], colorSelected);
			match.data.draw(pos);
		}

		double scrollbarHeight = max(2.0, barHeight*10.0/max(1.0, matches.length.log2)*2);
		int scrollbarOffset = cast(int)((barHeight*10.0 - scrollbarHeight)*launcher.selected/(max(1.0, matches.length))) + 1;
		dc.rect([0, barHeight+scrollbarOffset], [2, cast(int)scrollbarHeight], colorSelected);

		dc.mapdc(windowHandle, size[0], size[1]);
	}

	void sendUpdate(){
		if(!dc.dpy || !windowHandle)
			return;
		if(lastUpdate+10 > Clock.currSystemTick.msecs)
			return;
		lastUpdate = Clock.currSystemTick.msecs;
		XClientMessageEvent ev;
		ev.type = ClientMessage;
		ev.format = 8;
		XSendEvent(dc.dpy, windowHandle, false, 0, cast(XEvent*)&ev);
		XFlush(dc.dpy);
	}

	void handleEvents(){
		XEvent ev;
		while(running && !XNextEvent(dc.dpy, &ev)){
			if(XFilterEvent(&ev, windowHandle))
				continue;
			switch(ev.type){
			case Expose:
				if(ev.xexpose.count == 0)
					dc.mapdc(windowHandle, size[0], size[1]);
				break;
			case KeyPress:
				onKey(&ev.xkey);
				draw;
				break;
			case SelectionNotify:
				if(ev.xselection.property == utf8){
					char* p;
					int actualFormat;
					size_t count;
					Atom actualType;
					XGetWindowProperty(
						dc.dpy, windowHandle, utf8, 0, 1024, false, utf8,
						&actualType, &actualFormat, &count, &count, cast(ubyte**)&p
					);
					launcher.insert(p.to!string);
					XFree(p);
					draw;
				}
				break;
			case VisibilityNotify:
				if(ev.xvisibility.state != VisibilityUnobscured)
					XRaiseWindow(dc.dpy, windowHandle);
				break;
			case ClientMessage:
				draw;
				break;
			default: break;
			}
		}
	}

	private long lastUpdate;

	void onKey(XKeyEvent* ev){
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
					launcher.deleteLeft;
					return;
				case XK_BackSpace:
					launcher.deleteWordLeft;
					return;
				case XK_Delete:
					launcher.deleteWordRight;
					return;
				case XK_V:
				case XK_v:
					XConvertSelection(dc.dpy, clip, utf8, utf8, windowHandle, CurrentTime);
					return;
				default:
					return;
			}
		switch(key){
			case XK_Escape:
				running = false;
				return;
			case XK_Delete:
				launcher.delChar;
				return;				
			case XK_BackSpace:
				launcher.delBackChar;
				return;
			case XK_Left:
				if(launcher.cursor > 0)
					launcher.cursor--;
				return;
			case XK_Right:
				if(launcher.cursor < launcher.text.length)
					launcher.cursor++;
				return;
			case XK_Tab:
				launcher.selectNext;
				return;
			case XK_ISO_Left_Tab:
				launcher.selectPrev;
				return;
			case XK_Return:
			case XK_KP_Enter:
				launcher.run;
				return;
			default:
				break;
		}
		if(dc.textWidth(buf[0..length].to!string) > 0){
			string s = buf[0..length].to!string;
			launcher.insert(s);
			//if(s == " ")
			//	launcher.next;
			draw;
		}
	}

	void grabKeyboard(){
		foreach(i; 0..100){
			if(XGrabKeyboard(dc.dpy, DefaultRootWindow(dc.dpy), true, GrabModeAsync, GrabModeAsync, CurrentTime) == GrabSuccess)
				return;
			Thread.sleep(dur!"msecs"(10));
		}
		writeln("cannot grab keyboard");
	}

}

