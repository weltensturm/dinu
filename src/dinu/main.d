module dinu.main;


import dinu;


__gshared:


Options options;

CommandBuilder commandBuilder;

bool runProgram = true;

void delegate() close;

Display* display;
x11.X.Window root;

extern(C) nothrow int function(Display *, XErrorEvent *) xerror_default;
extern(C) nothrow int function(Display*) xerror_fatal_default;

shared static this(){
    debug(XSynchronize){
	    XSynchronize(wm.displayHandle, true);
    }
    display = wm.displayHandle;
    XSynchronize(display, true);
	xerror_default = XSetErrorHandler(&xerror);
    xerror_fatal_default = XSetIOErrorHandler(&xerror_fatal);
	root = RootWindow(display, 0);
}


enum XRequestCode {
    X_CreateWindow                   = 1,
    X_ChangeWindowAttributes         = 2,
    X_GetWindowAttributes            = 3,
    X_DestroyWindow                  = 4,
    X_DestroySubwindows              = 5,
    X_ChangeSaveSet                  = 6,
    X_ReparentWindow                 = 7,
    X_MapWindow                      = 8,
    X_MapSubwindows                  = 9,
    X_UnmapWindow                   = 10,
    X_UnmapSubwindows               = 11,
    X_ConfigureWindow               = 12,
    X_CirculateWindow               = 13,
    X_GetGeometry                   = 14,
    X_QueryTree                     = 15,
    X_InternAtom                    = 16,
    X_GetAtomName                   = 17,
    X_ChangeProperty                = 18,
    X_DeleteProperty                = 19,
    X_GetProperty                   = 20,
    X_ListProperties                = 21,
    X_SetSelectionOwner             = 22,
    X_GetSelectionOwner             = 23,
    X_ConvertSelection              = 24,
    X_SendEvent                     = 25,
    X_GrabPointer                   = 26,
    X_UngrabPointer                 = 27,
    X_GrabButton                    = 28,
    X_UngrabButton                  = 29,
    X_ChangeActivePointerGrab       = 30,
    X_GrabKeyboard                  = 31,
    X_UngrabKeyboard                = 32,
    X_GrabKey                       = 33,
    X_UngrabKey                     = 34,
    X_AllowEvents                   = 35,
    X_GrabServer                    = 36,
    X_UngrabServer                  = 37,
    X_QueryPointer                  = 38,
    X_GetMotionEvents               = 39,
    X_TranslateCoords               = 40,
    X_WarpPointer                   = 41,
    X_SetInputFocus                 = 42,
    X_GetInputFocus                 = 43,
    X_QueryKeymap                   = 44,
    X_OpenFont                      = 45,
    X_CloseFont                     = 46,
    X_QueryFont                     = 47,
    X_QueryTextExtents              = 48,
    X_ListFonts                     = 49,
    X_ListFontsWithInfo             = 50,
    X_SetFontPath                   = 51,
    X_GetFontPath                   = 52,
    X_CreatePixmap                  = 53,
    X_FreePixmap                    = 54,
    X_CreateGC                      = 55,
    X_ChangeGC                      = 56,
    X_CopyGC                        = 57,
    X_SetDashes                     = 58,
    X_SetClipRectangles             = 59,
    X_FreeGC                        = 60,
    X_ClearArea                     = 61,
    X_CopyArea                      = 62,
    X_CopyPlane                     = 63,
    X_PolyPoint                     = 64,
    X_PolyLine                      = 65,
    X_PolySegment                   = 66,
    X_PolyRectangle                 = 67,
    X_PolyArc                       = 68,
    X_FillPoly                      = 69,
    X_PolyFillRectangle             = 70,
    X_PolyFillArc                   = 71,
    X_PutImage                      = 72,
    X_GetImage                      = 73,
    X_PolyText8                     = 74,
    X_PolyText16                    = 75,
    X_ImageText8                    = 76,
    X_ImageText16                   = 77,
    X_CreateColormap                = 78,
    X_FreeColormap                  = 79,
    X_CopyColormapAndFree           = 80,
    X_InstallColormap               = 81,
    X_UninstallColormap             = 82,
    X_ListInstalledColormaps        = 83,
    X_AllocColor                    = 84,
    X_AllocNamedColor               = 85,
    X_AllocColorCells               = 86,
    X_AllocColorPlanes              = 87,
    X_FreeColors                    = 88,
    X_StoreColors                   = 89,
    X_StoreNamedColor               = 90,
    X_QueryColors                   = 91,
    X_LookupColor                   = 92,
    X_CreateCursor                  = 93,
    X_CreateGlyphCursor             = 94,
    X_FreeCursor                    = 95,
    X_RecolorCursor                 = 96,
    X_QueryBestSize                 = 97,
    X_QueryExtension                = 98,
    X_ListExtensions                = 99,
    X_ChangeKeyboardMapping         = 100,
    X_GetKeyboardMapping            = 101,
    X_ChangeKeyboardControl         = 102,
    X_GetKeyboardControl            = 103,
    X_Bell                          = 104,
    X_ChangePointerControl          = 105,
    X_GetPointerControl             = 106,
    X_SetScreenSaver                = 107,
    X_GetScreenSaver                = 108,
    X_ChangeHosts                   = 109,
    X_ListHosts                     = 110,
    X_SetAccessControl              = 111,
    X_SetCloseDownMode              = 112,
    X_KillClient                    = 113,
    X_RotateProperties              = 114,
    X_ForceScreenSaver              = 115,
    X_SetPointerMapping             = 116,
    X_GetPointerMapping             = 117,
    X_SetModifierMapping            = 118,
    X_GetModifierMapping            = 119,
    X_NoOperation                   = 127
}

extern(C) nothrow int xerror(Display* dpy, XErrorEvent* ee){
	if(ee.error_code == XErrorCode.BadWindow
	|| (ee.request_code == X_SetInputFocus && ee.error_code == XErrorCode.BadMatch)
	|| (ee.request_code == X_PolyText8 && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_PolyFillRectangle && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_PolySegment && ee.error_code == XErrorCode.BadDrawable)
	|| (ee.request_code == X_ConfigureWindow && ee.error_code == XErrorCode.BadMatch)
	|| (ee.request_code == X_GrabButton && ee.error_code == XErrorCode.BadAccess)
	|| (ee.request_code == X_GrabKey && ee.error_code == XErrorCode.BadAccess)
	|| (ee.request_code == X_CopyArea && ee.error_code == XErrorCode.BadDrawable))
		return 0;
	try{
		defaultTraceHandler.toString.writeln;
		"dinu: X11 error: request code=%d %s, error code=%d %s".format(
                ee.request_code,
                cast(XRequestCode)ee.request_code,
                ee.error_code,
                cast(XErrorCode)ee.error_code
        ).writeln;
	}catch(Throwable) {}
	return xerror_default(dpy, ee); /* may call exit */
}

extern(C) nothrow int xerror_fatal(Display* dpy){
    try{
        defaultTraceHandler.toString.writeln;
        "dinu: X11 fatal i/o error".writeln;
    }catch(Throwable) {}
    return xerror_fatal_default(dpy);
}

struct Options {

	@("-h") bool help;

	@("-x") int x;
	@("-y") int y;
	@("-w") int w;
	@("-s") int screen = 0;
	@("-l") int lines = 15;
	@("-fn") string font = "Monospace-10";
	@("-fo") string fontOutput = "Monospace-10";
	@("-c") string configPath = "~/.dinu/default";

	@("-r") double ratio = 0.25;

	@("-e") string execute;

	@("-a") double animations = 1;
	@("-as") double animationMove = 1;

	@("-f") bool flatman;

	@("-cb") float[3] colorBg = "#222222".color;
	@("-ci") float[3] colorInput = "#ffffff".color;
	@("-cib") float[3] colorInputBg = "#454545".color;
	@("-co") float[3] colorOutput = "#eeeeee".color;
	@("-cob") float[3] colorOutputBg = "#111111".color;
	@("-ce") float[3] colorError = "#ff7777".color;
	@("-cs") float[3] colorSelected = "#005577".color;
	@("-ch") float[3] colorHint = "#999999".color;
	@("-chb") float[3] colorHintBg = "#444444".color;
	@("-cd") float[3] colorDir = "#bbeebb".color;
	@("-cf") float[3] colorFile = "#eeeeee".color;
	@("-ce") float[3] colorExec = "#bbbbff".color;
	@("-cde") float[3] colorDesktop = "#bdddff".color;
	@("-cde") float[3] colorWindow = "#ffdd88".color;

    @("-dd") int directoryDepth = -1;

}


void main(string[] args){
	try {
        writeln(args);
		options.fill(args);
		if(options.help){
			options.usage;
			return;
		}
		try{
			options.configPath = options.configPath.expandTilde;
			if(!options.configPath.dirName.exists)
				mkdirRecurse(options.configPath.dirName);
			if(options.configPath.exists)
				chdir(options.configPath.expandTilde.readText.strip);
		}catch(Exception e){
			writeln(e);
		}
		windowLoop;
	}catch(Throwable t){
		writeln(t);
	}
}

void windowLoop(){
	commandBuilder = new CommandBuilder;

	auto windowMain = new WindowMain;
    wm.add(windowMain);
    windowMain.show;
	windowMain.draw;

	auto windowResults = new ResultWindow;
    wm.add(windowResults);
	windowMain.resultWindow = windowResults;

	close = {
        windowMain.close;
        windowResults.close;
		runProgram = false;
	};

	if(options.execute.length){
		commandBuilder.text = options.execute.to!dstring;
		commandBuilder.run;
	}

	scope(exit)
		close();

	long last = (now*1000).lround;
	while(wm.hasActiveWindows){
        wm.processEvents;
        if(windowMain.isActive){
            windowMain.update;
            windowMain.onDraw;
            if(windowResults.isActive){
                windowResults.update(windowMain);
                windowResults.onDraw;
            }
        }
		auto curr = (now*1000).lround;
		last = curr;
		Thread.sleep((15 - max(0, min(15, curr-last))).msecs);
	}
}



