module dinu.window;

import
	dinu.xapp,
	draw,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef;

class Window {
 
	XApp wm;
	x11.X.Window handle;
	bool open;
	int[2] pos;
	int[2] size;
	DrawingContext dc;
	bool active;

	this(XApp wm, int[2] pos, int[2] size){
		this.wm = wm;
		auto screen = DefaultScreen(wm.display);
		XSetWindowAttributes attributes;
		attributes.override_redirect = true;
		attributes.background_pixel = true;
		attributes.event_mask = ExposureMask | KeyPressMask | VisibilityChangeMask | StructureNotifyMask;
		handle = XCreateWindow(
			wm.display,
			RootWindow(wm.display, screen),
			pos[0],
			pos[1],
			size[0],
			size[1],
			0,
			DefaultDepth(wm.display, screen),
			CopyFromParent,
			DefaultVisual(wm.display, screen),
			CWOverrideRedirect | CWBackPixel | CWEventMask,
			&attributes
		);
		this.pos = pos;
		this.size = size;
		dc = new DrawingContext;
		dc.resizedc(size[0], size[1]);
		open = true;
	}

	void handleEvents(){
		XEvent ev;
		while(XPending(wm.display)){
			XNextEvent(wm.display, &ev);
			if(XFilterEvent(&ev, handle))
				continue;
			switch(ev.type){
				case VisibilityNotify:
					if(ev.xvisibility.state != VisibilityUnobscured)
						XRaiseWindow(wm.display, handle);
					break;
				case ConfigureNotify:
					if(size[0] != ev.xconfigure.width || size[1] != ev.xconfigure.height){
						size[0] = ev.xconfigure.width;
						size[1] = ev.xconfigure.height;
						dc.resizedc(size[0], size[1]);
					}
					if(pos[0] != ev.xconfigure.x || pos[1] != ev.xconfigure.y){
						pos[0] = ev.xconfigure.x;
						pos[1] = ev.xconfigure.y;
					}
					break;
				default:break;
			}
		}
	}

	void hide(){
		if(!active)
			return;
		XUnmapWindow(wm.display, handle);
		active = false;
	}

	void show(){
		if(active)
			return;
		XMapWindow(wm.display, handle);
		active = true;
	}

	void resize(int[2] size){
		XResizeWindow(wm.display, handle, size[0], size[1]);
		this.size = size;
	}

	void move(int[2] pos){
		XMoveWindow(wm.display, handle, pos[0], pos[1]);
		this.pos = pos;
	}

	void close(){
		if(!open)
			return;
		open = false;
		//XUnmapWindow(wm.display, handle);
		XDestroyWindow(wm.display, handle);
	}

	void draw(){
	}

}

