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
	dinu.draw,
	dinu.cli,
	dinu.util,
	dinu.window,
	dinu.animation,
	dinu.commandBuilder,
	dinu.command,
	dinu.dinu,
	ws.x.desktop,
	x11.X,
	x11.Xlib,
	x11.extensions.Xinerama,
	x11.keysymdef;

__gshared:



private double em1;

int em(double mod){
	return cast(int)(round(em1*mod));
}

double eerp(double current, double target, double speed){
	auto dir = current > target ? -1 : 1;
	auto spd = abs(target-current)*speed+speed;
	spd = spd.min(abs(target-current)).max(0);
	return current + spd*dir;
}

struct Screen {
	int x, y, w, h;
}


Screen[int] screens(Display* display){
	int count;
	auto screenInfo = XineramaQueryScreens(display, &count);
	Screen[int] res;
	foreach(screen; screenInfo[0..count])
		res[screen.screen_number] = Screen(screen.x_org, screen.y_org, screen.width, screen.height);
	XFree(screenInfo);
	return res;

}

class XClient: dinu.window.Window {

	dinu.window.Window resultWindow;
	int padding;
	int animationY;
	bool shouldClose;
	long lastUpdate;
	double animStart;
	double scrollCurrent = 0;
	double selectCurrent = 0;

	Animation windowAnimation;

	this(){
		super(0, [0, 0], [1,1]);
		dc.initfont(options.font);
		auto screens = screens(display);
		if(options.screen !in screens){
			"Screen %s does not exist".format(options.screen).writeln;
			options.screen = screens.keys[0];
		}
		auto screen = screens[options.screen];
		em1 = dc.font.height*1.3;
		resize([
			options.w ? options.w : screen.w,
			1.em*(options.lines+1)+0.8.em
		]);
		move([
			options.x + screen.x,
			-size.h
		]);
		show;
		grabKeyboard;
		padding = 0.4.em;
		lastUpdate = Clock.currSystemTick.msecs;
		windowAnimation = new AnimationExpIn(pos.y, 0, (0.1+size.h/4000.0)*options.animations);
	}

	void update(){
		auto cur = Clock.currSystemTick.msecs;
		auto delta = cur-lastUpdate;
		lastUpdate = cur;
		int targetY = cast(int)windowAnimation.calculate;
		if(targetY != pos.y)
			move([pos.x, targetY]);
		else if(windowAnimation.done && shouldClose)
			super.destroy;
		auto matches = output.dup;
		auto selected = commandBuilder.selected < -1 ? -commandBuilder.selected-2 : -1;
		auto scrollTarget = min(max(0, cast(long)matches.length-cast(long)options.lines), max(0, selected+1-options.lines/2));
		if(options.animations > 0){
			scrollCurrent = scrollCurrent.eerp(scrollTarget, delta/150.0);
			selectCurrent = selectCurrent.eerp(commandBuilder.selected, delta/50.0);
		}else{
			scrollCurrent = scrollTarget;
			selectCurrent = commandBuilder.selected;
		}
	}

	override void draw(){
		if(!active)
			return;
		assert(thread_isMainThread);

		int separator = size.w/4;
		drawOutput([0, 0], [size.w, 1.em*options.lines], separator);
		drawInput([0, options.lines*1.em], [size.w, size.h-1.em*options.lines], separator);
		super.draw;
	}

	void drawInput(int[2] pos, int[2] size, int sep){
		auto paddingVert = 0.2.em;
		dc.rect(pos, size, options.colorBg);
		dc.rect([sep, pos.y+paddingVert], [size.w/2, size.h-paddingVert*2], options.colorInputBg);
		// cwd
		int textY = pos.y+size.h/2-0.5.em;
		dc.text([pos.x+sep, textY], getcwd, commandBuilder.commandHistory ? options.colorExec : options.colorHint, 1.4);
		dc.clip([pos.x+size.w/4, pos.y], [size.w/2, size.h]);
		int textWidth = dc.textWidth(commandBuilder.cursorPart ~ "..");
		int offset = -max(0, textWidth-size.w/2);
		int textStart = offset+pos.x+sep+padding;
		// cursor
		auto selStart = min(commandBuilder.cursor, commandBuilder.cursorStart);
		auto selEnd = max(commandBuilder.cursor, commandBuilder.cursorStart);
		int cursorOffset = padding+offset+pos.x+sep+dc.textWidth(commandBuilder.finishedPart);
		int selpos = cursorOffset+dc.textWidth(commandBuilder.text[0..selEnd]);
		if(commandBuilder.cursorStart != commandBuilder.cursor){
			auto start = cursorOffset+dc.textWidth(commandBuilder.text[0..selStart]);
			dc.rect([start, pos.y+paddingVert*2], [selpos-start, size.y-paddingVert*4], options.colorHint);
		}
		int curpos = cursorOffset+dc.textWidth(commandBuilder.text[0..commandBuilder.cursor]);
		dc.rect([curpos, pos.y+paddingVert*2], [1, size.y-paddingVert*4], options.colorInput);
		// input
		if(!commandBuilder.commandSelected){
			dc.text([textStart, textY], commandBuilder.toString, options.colorInput);
		}else{
			auto xoff = textStart+commandBuilder.commandSelected.draw(dc, [textStart, textY], false);
			foreach(param; commandBuilder.command[1..$])
				xoff += dc.text([xoff, textY], param ~ ' ', options.colorInput);
		}
		dc.noclip;
	}

	void drawOutput(int[2] pos, int[2] size, int sep){
		dc.rect(pos, size, options.colorOutputBg);
		auto matches = output.dup;
		auto selected = commandBuilder.selected < -1 ? -commandBuilder.selected-2 : -1;
		auto start = cast(size_t)scrollCurrent;
		if(selectCurrent < -1)
			dc.rect([pos.x+sep, cast(int)(pos.y+size.h - size.h*(-1-selectCurrent-scrollCurrent)/cast(double)options.lines)], [size.w/2, 1.em], options.colorHintBg);
		foreach(i, match; matches[start..min($, start+options.lines+1)]){
			int y = cast(int)(pos.y+size.h - size.h*(i+1-(scrollCurrent-start))/cast(double)options.lines);
			dc.clip([pos.x, pos.y], [size.w/4*3, size.h]);
			match.draw(dc, [pos.x+sep+padding, y], start+i == selected);
			dc.noclip;
		}
		if(matches.length > 15){
			double scrollbarHeight = size.h/(max(1.0, (cast(long)matches.length-cast(long)14).log2));
			int scrollbarOffset = cast(int)((size.h - scrollbarHeight) * (1-scrollCurrent/(max(1.0, matches.length-15))));
			dc.rect([size.w/4*3-0.2.em, scrollbarOffset], [0.2.em, cast(int)scrollbarHeight], options.colorHintBg);
		}
	}

	void showOutput(){
		options.lines = 15;
		int height = 1.em*(options.lines+1)+0.8.em-1;
		XResizeWindow(display, handle, size.w, height);
		XMoveWindow(display, handle, pos.x, pos.y-height+size.h);
		windowAnimation = new AnimationExpIn(pos.y-height+size.h, options.y, (0.1+size.h/4000.0)*options.animations);
	}

	override void destroy(){
		windowAnimation = new AnimationExpOut(pos.y, -size.h, (0.1+size.h/4000.0)*options.animations);
		shouldClose = true;
		XUngrabKeyboard(display, CurrentTime);
	}

	override void onKey(XKeyEvent* ev){
		char[5] buf;
		KeySym key;
		Status status;
		auto length = Xutf8LookupString(xic, ev, buf.ptr, cast(int)buf.length, &key, &status);
		if(ev.state & ControlMask)
			switch(key){
				case XK_r:
					commandBuilder.commandHistory = true;
					commandBuilder.resetFilter;
					return;
				case XK_q:
					key = XK_Escape;
					break;
				case XK_u:
					commandBuilder.deleteLeft;
					return;
				case XK_BackSpace:
					commandBuilder.deleteWordLeft;
					return;
				case XK_Delete:
					commandBuilder.deleteWordRight;
					return;
				case XK_j:
					commandBuilder.moveLeft;
					return;
				case XK_semicolon:
					commandBuilder.moveRight;
					return;
				case XK_V:
				case XK_v:
					XConvertSelection(display, clip, utf8, utf8, handle, CurrentTime);
					return;
				case XK_a:
					commandBuilder.selectAll;
					return;
				default:
					break;
			}
		switch(key){
			case XK_Escape:
				close();
				return;
			case XK_Delete:
				commandBuilder.delChar;
				return;				
			case XK_BackSpace:
				commandBuilder.delBackChar;
				return;
			case XK_Left:
				commandBuilder.moveLeft((ev.state & ControlMask) != 0);
				return;
			case XK_Right:
				commandBuilder.moveRight((ev.state & ControlMask) != 0);
				return;
			case XK_Tab:
			case XK_Down:
				commandBuilder.select(commandBuilder.selected+1);
				return;
			case XK_ISO_Left_Tab:
			case XK_Up:
				if(!options.lines && commandBuilder.selected == -1){
					showOutput;
				}else
					commandBuilder.select(commandBuilder.selected-1);
				return;
			case XK_Page_Up:
				commandBuilder.select(commandBuilder.selected-options.lines);
				break;
			case XK_Page_Down:
				commandBuilder.select(commandBuilder.selected+options.lines);
				break;
			case XK_Return:
			case XK_KP_Enter:
				commandBuilder.run(!(ev.state & ControlMask));
				if(ev.state & ShiftMask && !options.lines){
					showOutput;
				}
				if(!(ev.state & ControlMask) && !(ev.state & ShiftMask))
					close();
				return;
			case XK_Shift_L:
			case XK_Shift_R:
				commandBuilder.shiftDown = !commandBuilder.shiftDown;
				break;
			default:
				break;
		}
		if(dc.textWidth(buf[0..length].to!string) > 0){
			string s = buf[0..length].to!string;
			commandBuilder.insert(s);
		}
		draw;
	}

	override void onPaste(string text){
		commandBuilder.insert(text);
	}

	void grabKeyboard(){
		foreach(i; 0..100){
			if(XGrabKeyboard(display, DefaultRootWindow(display), true, GrabModeAsync, GrabModeAsync, CurrentTime) == GrabSuccess)
				return;
			Thread.sleep(dur!"msecs"(10));
		}
		close();
		assert(0, "cannot grab keyboard");
	}

}

