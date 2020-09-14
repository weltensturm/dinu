module dinu.mainWindow;


import dinu;
 
 
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


auto mapKeyToChar(ws.wm.Window window, XKeyEvent* e, void delegate(dchar) cb){
    char[25] str;
    KeySym ks;
    Status st;
    size_t l = Xutf8LookupString(window.inputContext, e, str.ptr, 25, &ks, &st);
    foreach(dchar c; str[0..l])
        if(!c.isControl)
            cb(c);
}


class WindowMain: ws.wm.Window {

    ws.wm.Window resultWindow;
    int padding;
    int animationY;
    bool shouldClose;
    long lastUpdate;
    double animStart;
    double scrollCurrent = 0;
    double selectCurrent = 0;

    Animation windowAnimation;

    //GlContext context;

    this(){
        super(1, 1, "dinu", true);
        draw.setFont(options.font, 12);
        auto screens = screens(display);
        if(options.screen !in screens){
            "Screen %s does not exist".format(options.screen).writeln;
            options.screen = screens.keys[0];
        }
        auto screen = screens[options.screen];
        em1 = draw.fontHeight*1.2;
        //context.blendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        //context.enable(GL_BLEND);
        resize([
            options.w ? options.w : screen.w,
            1.em*(options.lines+1)+0.8.em
        ]);
        move([
            options.x + screen.x,
            options.y - size.h
        ]);
        show;
        grabKeyboard;
        padding = 0.4.em;
        lastUpdate = (now*1000).lround;
        windowAnimation = new AnimationExpIn(pos.y, 0, (0.1+size.h/4000.0)*options.animationMove);
        wm.on([
            KeyPress: (XEvent* e){ keyboard(cast(Keyboard.key)XLookupKeysym(&e.xkey,0), true); this.mapKeyToChar(&e.xkey, &keyboard); },
            KeyRelease: (XEvent* e) => keyboard(cast(Keyboard.key)XLookupKeysym(&e.xkey,0), false)
        ]);
    }

    /+
    override void drawInit(){
        context = new GlContext(windowHandle);
        draw = new GlDraw(context);
    }
    +/

    override void resized(int[2] size){
        super.resized(size);
        onDraw;
    }

    void update(){
        auto cur = (now*1000).lround;
        auto delta = cur-lastUpdate;
        lastUpdate = cur;
        int targetY = cast(int)windowAnimation.calculate+options.y;
        if(windowAnimation.done && shouldClose){
            writeln("CLOSE");
            super.close;
            return;
        }else if(targetY != pos.y){
            move([pos.x, targetY]);
        }
        auto matches = output.idup;
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

    override void onDraw(){
        if(hidden)
            return;
        assert(thread_isMainThread);

        int separator = (size.w*options.ratio).to!int;
        draw.clear;
        drawOutput([0, size.h-1.em*options.lines], [size.w, 1.em*options.lines], separator);
        drawInput([0, 0], [size.w, size.h-1.em*options.lines], separator);
        super.onDraw;
    }

    void drawInput(int[2] pos, int[2] size, int sep){
        auto paddingVert = 0.2.em;
        draw.setColor(options.colorBg);
        draw.rect(pos, size);
        draw.setColor(options.colorInputBg);
        draw.rect([sep, pos.y+paddingVert], [size.w - sep*2, 1]);

        // cwd
        int textY = pos.y + ((size.h - draw.fontHeight)/2.0).lround.to!int;
        //draw.setColor([1,0,0,0.1]);
        //draw.rect([0,textY], [size.w, draw.fontHeight]);
        auto context = getcwd.replace("~".expandTilde, "~").split("/");
        auto partAdvance = draw.width(context[$-1]~"/");
        draw.setColor(options.colorHint);
        draw.text([pos.x+sep-partAdvance, textY], context[0..$-1].join("/"), 1.4);
        if(context.length > 1)
            draw.text([pos.x+sep-partAdvance+draw.width("/"), textY], "/", 1.4);
        draw.setColor(options.colorOutput);
        draw.text([pos.x+sep, textY], context[$-1], 1.4);
        
        draw.clip([pos.x+sep, pos.y], [size.w - sep*2, size.h]);
        int width = draw.width(commandBuilder.cursorPart ~ "..");
        int offset = -max(0, width-size.w - sep*2);

        // cursor
        auto selStart = min(commandBuilder.cursor, commandBuilder.cursorStart);
        auto selEnd = max(commandBuilder.cursor, commandBuilder.cursorStart);
        int cursorOffset = padding+offset+pos.x+sep+draw.width(commandBuilder.finishedPart);
        int selpos = cursorOffset+draw.width(commandBuilder.text[0..selEnd].to!string);
        if(commandBuilder.cursorStart != commandBuilder.cursor){
            auto start = cursorOffset+draw.width(commandBuilder.text[0..selStart].to!string);
            draw.setColor(options.colorHint);
            draw.rect([start, pos.y+paddingVert*2], [selpos-start, size.y-paddingVert*4]);
        }
        int curpos = cursorOffset+draw.width(commandBuilder.text[0..commandBuilder.cursor].to!string);
        draw.setColor(options.colorInput);
        draw.rect([curpos, pos.y+paddingVert*2], [1, size.y-paddingVert*4]);

        // input
        int textStart = offset+pos.x+sep+padding;
        if(!commandBuilder.commandSelected){
            draw.text([textStart, textY], commandBuilder.toString, 0);
        }else{
            auto xoff = textStart+commandBuilder.commandSelected[0].draw(draw, [textStart, textY], false, []);
            draw.setColor(options.colorInput);
            foreach(param; commandBuilder.command[1..$])
                xoff += draw.text([xoff, textY], ' ' ~ param.to!string, 0);
        }
        draw.noclip;
        //draw.text([10, textY], commandBuilder.toString.expandTilde.buildNormalizedPath, 0);
    }

    void drawOutput(int[2] pos, int[2] size, int sep){
        draw.setColor(options.colorOutputBg);
        draw.rect(pos, size);
        auto output = output.idup;
        auto selected = commandBuilder.selected < -1 ? -commandBuilder.selected-2 : -1;
        auto start = cast(size_t)scrollCurrent;
        auto textOffset = ((1.em - draw.fontHeight)/2.0).lround.to!int;
        if(selectCurrent < -1){
            draw.setColor(options.colorHintBg);
            draw.rect([pos.x+sep, cast(int)(pos.y + size.h*(-2-selectCurrent-scrollCurrent)/cast(double)options.lines)], [size.w-sep*2, 1.em]);
        }
        foreach(i, match; output[start..min($, start+options.lines+1)]){
            int y = cast(int)(pos.y + size.h*(i-(scrollCurrent-start))/cast(double)options.lines) + textOffset;
            draw.clip([pos.x, pos.y], [size.w-sep, size.h]);
            match.draw(draw, [pos.x+sep+padding, y], start+i == selected, []);
            draw.noclip;
            debug(Score){
                draw.setColor(options.colorInput);
                draw.text([size.w-sep, y], match.score.to!string);
            }
        }
        if(output.length > 15){
            double scrollbarHeight = size.h/(max(1.0, (cast(long)output.length-cast(long)14).log2));
            int scrollbarOffset = cast(int)((size.h - scrollbarHeight) * (scrollCurrent/(max(1.0, output.length-15))));
            draw.setColor(options.colorHintBg);
            draw.rect([size.w-sep-0.2.em, scrollbarOffset], [0.2.em, cast(int)scrollbarHeight]);
        }
    }

    void showOutput(){
        if(hidden)
            return;
        options.lines = 15;
        int height = 1.em*(options.lines+1)+0.8.em-1;
        resize([size.w, height]);
        move([pos.x, pos.y-height+size.h]);
        windowAnimation = new AnimationExpIn(pos.y-height+size.h, options.y, (0.1+size.h/4000.0)*options.animationMove);
    }

    override void close(){
        XUngrabKeyboard(wm.displayHandle, CurrentTime);
        commandBuilder.destroy;
        windowAnimation = new AnimationExpOut(pos.y, -size.h, (0.1+size.h/4000.0)*options.animationMove);
        shouldClose = true;
        //super.close();
    }

    bool[Keyboard.key] keys;

    void keyboard(Keyboard.key key, bool pressed){
        keys[key] = pressed;
        if(!pressed)
            return;
        auto control = keys.get(Keyboard.control, false) || keys.get(Keyboard.controlR, false);
        auto shift = keys.get(Keyboard.shift, false) || keys.get(Keyboard.shiftR, false);
        if(control)
            switch(key){
                case XK_q:			key = XK_Escape; break;
                case XK_u:			commandBuilder.deleteLeft; return;
                case XK_BackSpace:	commandBuilder.deleteWordLeft; return;
                case XK_Delete:		commandBuilder.deleteWordRight; return;
                case XK_j:			commandBuilder.moveLeft; return;
                case XK_semicolon:	commandBuilder.moveRight; return;
                case XK_V:
                //case XK_v:			XConvertSelection(display, clip, utf8, utf8, handle, CurrentTime); return;
                case XK_a:			commandBuilder.selectAll; return;
                default: break;
            }
        switch(key){
            case XK_Escape:			.close(); return;
            case XK_Delete:			commandBuilder.delChar; return;
            case XK_BackSpace:		commandBuilder.delBackChar; return;
            case XK_Left:			commandBuilder.moveLeft(control); return;
            case XK_Right:			commandBuilder.moveRight(control); return;
            case XK_Down:			commandBuilder.select(commandBuilder.selected+1); return;
            case XK_Tab:			if(!shift){
                                        commandBuilder.select(commandBuilder.selected+1); return;
                                    }else{
                                        goto case XK_Up;
                                    }
            case XK_Up:
                                    if(!options.lines && commandBuilder.selected == -1){
                                        showOutput;
                                    }else
                                        commandBuilder.select(commandBuilder.selected-1);
                                    return;
            case XK_Page_Up:		commandBuilder.select(commandBuilder.selected-15);
                                    if(commandBuilder.selected < 0)
                                        showOutput;
                                    break;
            case XK_Page_Down:		commandBuilder.select(commandBuilder.selected+15); break;
            case XK_Return:
            case XK_KP_Enter:
                                    commandBuilder.run(!control);
                                    if(shift && !options.lines){
                                        showOutput;
                                    }
                                    if(!control && !shift)
                                        .close();
                                    return;
            case Keyboard.shift:
            case Keyboard.shiftR:	commandBuilder.shiftDown = !commandBuilder.shiftDown; break;
            default: break;
        }
        onDraw;
    }

    void keyboard(dchar key){
        commandBuilder.insert(key.to!dstring);
        onDraw;
    }

    override void onPaste(string text){
        commandBuilder.insert(text.to!dstring);
    }

    void grabKeyboard(){
        foreach(i; 0..100){
            if(XGrabKeyboard(display, windowHandle, true, GrabModeAsync, GrabModeAsync, CurrentTime) == GrabSuccess)
                return;
            Thread.sleep(dur!"msecs"(10));
        }
        .close();
        assert(0, "cannot grab keyboard");
    }

}

