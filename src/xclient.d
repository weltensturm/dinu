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
	dinu.window,
	dinu.launcher,
	dinu.command,
	dinu.dinu,
	desktop,
	x11.X,
	x11.Xlib,
	x11.keysymdef;

__gshared:



ref T x(T)(ref T[2] a){
	return a[0];
}
alias w = x;

ref T y(T)(ref T[2] a){
	return a[1];
}
alias h = y;


private double em1;

int em(double mod){
	return cast(int)(round(em1*1.3*mod));
}


class XClient: dinu.window.Window {

	this(){
		super(options.screen, [options.x, options.y], [1,1]);
		dc.initfont(options.font);
		em1 = dc.font.height;
		resize([
			options.w ? options.w : DisplayWidth(display, screen),
			options.h ? options.h : 1.em*(options.lines+1)+0.8.em
		]);
		show;
		grabKeyboard;
	}

	override void draw(){
		if(!active)
			return;
		assert(thread_isMainThread);
		dc.rect([0,0], [size.w, size.h], options.colorBg);
		int separator = size.w/4;
		drawInput([0, options.lines*1.em+0.2.em], [size.w, 1.4.em], separator);
		drawMatches([0, 0], [size.w, 1.em*options.lines], separator);
		super.draw;
	}

	void drawInput(int[2] pos, int[2] size, int sep){
		dc.rect([sep, pos.y], [size.w/2, size.h], options.colorInputBg);
		// cwd
		dc.text([pos.x+sep, pos.y+dc.font.height-1+0.2.em], getcwd, options.colorHint, 1.4);
		dc.clip([pos.x+size.w/4, pos.y], [size.w/2, size.h]);
		int textWidth = dc.textWidth(launcher.toString[0..launcher.cursor] ~ ".");
		int offset = -max(0, textWidth-size.w/2);
		// input
		dc.text([offset+pos.x+sep+0.2.em, pos.y+dc.font.height-1+0.2.em], launcher.toString, options.colorInput);
		// cursor
		int cursorOffset = dc.textWidth(launcher.finishedPart);
		int curpos = offset+pos.x+sep+cursorOffset+0.2.em + dc.textWidth(launcher.toString[0..launcher.cursor]);
		dc.rect([curpos, pos.y+0.2.em], [1, size.y-0.4.em], options.colorInput);
		dc.noclip;
	}

	void drawMatches(int[2] pos, int[2] size, int sep){
		dc.rect(pos, size, options.colorOutputBg);
		auto matches = output.res;
		auto selected = launcher.selected < -1 ? -launcher.selected-2 : -1;
		long start = min(max(0, cast(long)matches.length-cast(long)options.lines), max(0, selected+1-options.lines/2));
		foreach(i, match; matches[start..min($, start+options.lines)]){
			int y = cast(int)(pos.y+size.h - size.h*(i+1)/cast(double)options.lines);
			if(start+i == selected)
				dc.rect([pos.x+sep, y], [size.w/2, 1.em], options.colorHintBg);
			dc.clip([pos.x, pos.y], [size.w/4*3, size.h]);
			match.data.draw(dc, [pos.x+sep+0.1.em, y+dc.font.height-1], start+i == selected);
			dc.noclip;
		}
	}

	override void onKey(XKeyEvent* ev){
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
					XConvertSelection(display, clip, utf8, utf8, handle, CurrentTime);
					return;
				default:
					break;
			}
		switch(key){
			case XK_Escape:
				destroy;
				return;
			case XK_Delete:
				launcher.delChar;
				return;				
			case XK_BackSpace:
				launcher.delBackChar;
				return;
			case XK_Left:
				launcher.moveLeft((ev.state & ControlMask) != 0);
				return;
			case XK_Right:
				launcher.moveRight((ev.state & ControlMask) != 0);
				return;
			case XK_Tab:
			case XK_Down:
				launcher.selectNext;
				return;
			case XK_ISO_Left_Tab:
			case XK_Up:
				if(!options.lines && launcher.selected == -1){
					options.lines = 15;
					int height = options.h ? options.h : 1.em*(options.lines+1)+0.8.em-1;
					XResizeWindow(display, handle, size.w, height);
				}else
					launcher.selectPrev;
				return;
			case XK_Return:
			case XK_KP_Enter:
				launcher.run(!(ev.state & ControlMask));
				if(ev.state & ShiftMask){
					options.lines = 15;
					int height = options.h ? options.h : 1.em*(options.lines+1)+0.8.em-1;
					XResizeWindow(display, handle, size.w, height);
				}else if(!(ev.state & ControlMask))
					destroy;
				return;
			default:
				break;
		}
		if(dc.textWidth(buf[0..length].to!string) > 0){
			string s = buf[0..length].to!string;
			launcher.insert(s);
		}
		draw;
	}

	override void onPaste(string text){
		launcher.insert(text);
	}

	void grabKeyboard(){
		foreach(i; 0..100){
			if(XGrabKeyboard(display, DefaultRootWindow(display), true, GrabModeAsync, GrabModeAsync, CurrentTime) == GrabSuccess)
				return;
			Thread.sleep(dur!"msecs"(10));
		}
		assert(0, "cannot grab keyboard");
	}

}

