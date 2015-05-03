module dinu.xapp;

import
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef;

class XApp {

	Display* display;
	Window root;

	this(){
		display = XOpenDisplay(null);
		assert(display);
	}

}


