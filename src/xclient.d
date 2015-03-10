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
	dinu.command,
	dinu.dinu,
	desktop,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef;

__gshared:

int barHeight;

FontColor colorBg;
FontColor colorSelected;
FontColor colorText;
FontColor colorOutput;
FontColor colorOutputBg;
FontColor colorError;
FontColor colorDir;
FontColor colorFile;
FontColor colorExec;
FontColor colorHint;
FontColor colorDesktop;
FontColor colorInputBg;
Launcher launcher;

DrawingContext dc;
XClient client;



ref T x(T)(ref T[2] a){
	return a[0];
}
alias w = x;

ref T y(T)(ref T[2] a){
	return a[1];
}
alias h = y;

int em(double mod){
	return cast(int)(dc.font.height*1.3*mod);
}

void drawInput(int[2] pos, int[2] size, int sep){
	dc.rect(pos, size, colorInputBg);
	// cwd
	if(choiceFilter.commandHistory){
		dc.rect(pos, [sep-3, size.h], colorSelected);
		dc.text([pos.x+sep, pos.y+dc.font.height-1], getcwd ~ " | command history", colorOutput, 1.4);
	}else{
		dc.rect(pos, [sep-3, size.h], colorHint);
		dc.text([pos.x+sep, pos.y+dc.font.height-1], getcwd, colorBg, 1.4);
	}
	// input
	dc.text([pos.x+sep+0.1.em, pos.y+dc.font.height-1], launcher.toString, colorText);
	int offset = dc.textWidth(launcher.finishedPart);
	// cursor
	int curpos = pos.x+sep+offset+0.1.em + dc.textWidth(launcher.toString[0..launcher.cursor]);
	dc.rect([curpos, pos.y+0.1.em], [1, 0.8.em], colorText.id);
}

void drawMatches(int[2] pos, int[2] size, int sep){
	auto matches = choiceFilter.res;
	size_t start = cast(size_t)min(max(0, cast(long)matches.length-cast(long)options.lines), max(0, launcher.selected+1-options.lines/2));
	foreach(i, match; matches[start..min($, start+options.lines)]){
		int y = cast(int)(pos.y+size.h - size.h*(i+1)/cast(double)options.lines);
		if(start+i == launcher.selected)
			dc.rect([pos.x+sep-2, y], [size.w-sep, barHeight], colorSelected);
		match.data.draw([pos.x+sep+dc.textWidth(launcher.finishedPart)+0.1.em, y+dc.font.height-1], start+i == launcher.selected); 
	}
	double scrollbarHeight = size.h/(max(1.0, (cast(long)matches.length-cast(long)options.lines).log2));
	int scrollbarOffset = cast(int)((size.h - scrollbarHeight) * (1.0 - start/(max(1.0, matches.length-options.lines))));
	/+
	double scrollbarHeight = max(2.0, size.h/max(1.0, matches.length.log2)*2);
	int scrollbarOffset = cast(int)((size.h - scrollbarHeight)*(1.0 - max(0, start)/(max(1.0, matches.length)))) + 1;
	+/
	dc.rect([pos.x+sep-4, pos.y], [2, barHeight*options.lines], colorInputBg.id);
	if(matches.length){
		dc.rect([pos.x+sep-4, pos.y+scrollbarOffset], [2, cast(int)scrollbarHeight], colorSelected);
	}
}

class XClient {

	bool open = true;
	XIC xic;
	Atom clip;
	Atom utf8;
	Window windowHandle;
	int[2] size;
	long dt;

	this(){
		int screen = DefaultScreen(dc.dpy);
		int dimx, dimy, dimw, dimh;
		Window root = RootWindow(dc.dpy, screen);
		XSetWindowAttributes swa;
		XIM xim;
		clip = XInternAtom(dc.dpy, "CLIPBOARD",	false);
		utf8 = XInternAtom(dc.dpy, "UTF8_STRING", false);
		barHeight = 1.em;
		size.w = options.w ? options.w : DisplayWidth(dc.dpy, screen);
		size.h = options.h ? options.h : barHeight*(options.lines+1)+0.4.em;
		swa.override_redirect = true;
		swa.background_pixel = colorBg;
		swa.event_mask = ExposureMask | KeyPressMask | VisibilityChangeMask;
		windowHandle = XCreateWindow(
			dc.dpy, root, options.x, options.y, size[0], size[1], 0,
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
		draw;
	}

	void close(){
		if(!open)
			return;
		open = false;
		//XUnmapWindow(dc.dpy, windowHandle);
		XUngrabKeyboard(dc.dpy, CurrentTime);
		XDestroyWindow(dc.dpy, windowHandle);
	}

	void draw(){
		if(!open)
			return;
		assert(thread_isMainThread);
		dt = Clock.currSystemTick.msecs;
		dc.rect([0,0], size, colorBg);
		int separator = size.w/4; //dc.textWidth(getcwd)*2;
		drawInput([0, options.lines*barHeight+0.2.em], [size.w, barHeight], separator);
		drawMatches([0, 0], [size.w, barHeight*options.lines], separator);
		dc.mapdc(windowHandle, size.w, size.h);
	}


	void sendUpdate(){
		if(!dc.dpy || !windowHandle || !open)
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
		while(XPending(dc.dpy)){
			XNextEvent(dc.dpy, &ev);
		//while(open && !XNextEvent(dc.dpy, &ev)){
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
				case XK_r:
					launcher.toggleCommandHistory;
					return;
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
					break;
			}
		switch(key){
			case XK_Escape:
				close;
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
				launcher.run(!(ev.state & ControlMask));
				if(ev.state & ShiftMask)
					close;
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
		assert(0, "cannot grab keyboard");
	}

}

