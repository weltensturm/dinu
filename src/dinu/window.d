module dinu.window;

import
	std.conv,
	dinu.draw,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef;


__gshared:


class Window {
 
	x11.X.Window handle;
	int[2] pos;
	int[2] size;
	DrawingContext dc;
	bool active;
	Display* display;
	Atom clip;
	Atom utf8;
	int screen;
	XIC xic;

	this(int screen, int[2] pos, int[2] size){
		display = XOpenDisplay(null);
		this.screen = screen;
		XSetWindowAttributes attributes;
		attributes.override_redirect = true;
		attributes.background_pixel = true;
		attributes.event_mask = ExposureMask | KeyPressMask | VisibilityChangeMask | StructureNotifyMask;
		handle = XCreateWindow(
			display,
			RootWindow(display, screen),
			pos[0],
			pos[1],
			size[0],
			size[1],
			0,
			DefaultDepth(display, screen),
			CopyFromParent,
			DefaultVisual(display, screen),
			CWOverrideRedirect | CWEventMask,
			&attributes
		);
		clip = XInternAtom(display, "CLIPBOARD", false);
		utf8 = XInternAtom(display, "UTF8_STRING", false);
		auto xim = XOpenIM(display, null, null, null);
		xic = XCreateIC(
			xim, XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
			XNClientWindow, handle, XNFocusWindow, handle, null
		);
		this.pos = pos;
		this.size = size;
		dc = new DrawingContext;
		dc.resize(size);
	}

	void handleEvents(){
		XEvent ev;
		while(XPending(display)){
			XNextEvent(display, &ev);
			if(XFilterEvent(&ev, handle))
				continue;
			switch(ev.type){
				case KeyPress:
					onKey(&ev.xkey);
					break;
				case Expose:
					if(ev.xexpose.count == 0)
						draw;
					break;
				case VisibilityNotify:
					if(ev.xvisibility.state != VisibilityUnobscured)
						XRaiseWindow(display, handle);
					draw;
					break;
				case ConfigureNotify:
					if(size[0] != ev.xconfigure.width || size[1] != ev.xconfigure.height){
						size[0] = ev.xconfigure.width;
						size[1] = ev.xconfigure.height;
						dc.resize(size);
						draw;
					}
					if(pos[0] != ev.xconfigure.x || pos[1] != ev.xconfigure.y){
						pos[0] = ev.xconfigure.x;
						pos[1] = ev.xconfigure.y;
					}
					break;
				case ClientMessage:
					draw;
					break;
				case SelectionNotify:
					if(ev.xselection.property == utf8){
						char* p;
						int actualFormat;
						size_t count;
						Atom actualType;
						XGetWindowProperty(
							display, handle, utf8, 0, 1024, false, utf8,
							&actualType, &actualFormat, &count, &count, cast(ubyte**)&p
						);
						onPaste(p.to!string);
						XFree(p);
					}
					break;
				default:break;
			}
		}
	}

	void onPaste(string text){}

	void onKey(XKeyEvent* ev){}

	void hide(){
		if(!active)
			return;
		XUnmapWindow(display, handle);
		active = false;
	}

	void show(){
		if(active)
			return;
		XMapWindow(display, handle);
		active = true;
		draw;
	}

	void destroy(){
		if(!handle)
			return;
		hide;
		handleEvents;
		dc.destroy;
		XDestroyWindow(display, handle);
		XUngrabKeyboard(display, CurrentTime);
		handle = 0;
	}

	void resize(int[2] size){
		XResizeWindow(display, handle, size[0], size[1]);
		this.size = size;
		dc.resize(size);
	}

	void move(int[2] pos){
		XMoveWindow(display, handle, pos[0], pos[1]);
		this.pos = pos;
	}

	void draw(){
		dc.map(handle, size);
	}

}


shared static this(){
	XInitThreads();
}

