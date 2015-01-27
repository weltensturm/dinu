module draw;

import
	std.string,
	std.utf,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.keysymdef,

	dinu;


/* See LICENSE file for copyright and license details. */

struct ColorSet {
	ulong foreground;
	XftColor foreground_xft;
	ulong background;
}

struct Font {
	int ascent;
	int descent;
	int height;
	int width;
	int charWidth; // monospace ftw;
	XFontSet set;
	XFontStruct *xfont;
	XftFont *xft_font;
}

auto min(T1,T2: T1)(T1 a, T2 b){ return a < b ? a : b; }
auto max(T1,T2: T1)(T1 a, T2 b){ return a > b ? a : b; }




class DrawingContext {

	Bool invert;
	Display* dpy;
	GC gc;
	Pixmap canvas;
	XftDraw* xftdraw;
	Font font;

	this(){
		//if(!setlocale(LC_CTYPE, "") || !XSupportsLocale())
		//	fputs("no locale support", stderr);
		dpy = XOpenDisplay(null);
		if(!dpy)
			throw new Exception("cannot open display");

		gc = XCreateGC(dpy, DefaultRootWindow(dpy), 0, null);
		XSetLineAttributes(dpy, gc, 1, LineSolid, CapButt, JoinMiter);
	}

	void destroy(){
		freecol(colorNormal);
		freecol(colorSelected);
		//freecol(colorDim);

		if(font.xft_font){
			XftFontClose(dpy, font.xft_font);
			XftDrawDestroy(xftdraw);
		}
		if(font.set)
			XFreeFontSet(dpy, font.set);
		if(font.xfont)
			XFreeFont(dpy, font.xfont);
		if(canvas)
			XFreePixmap(dpy, canvas);
		if(gc)
			XFreeGC(dpy, gc);
		if(dpy)
			XCloseDisplay(dpy);
	}

	void drawrect(int x, int y, int w, int h, Bool fill, ulong color){
		XSetForeground(dpy, gc, color);
		if(fill)
			XFillRectangle(dpy, canvas, gc, x, y, w, h);
		else
			XDrawRectangle(dpy, canvas, gc, x, y, w-1, h-1);
	}


	void drawtext(int[2] pos, string text, ColorSet col){
		int x = pos[0];
		int y = pos[1];
		XSetForeground(dpy, gc, col.foreground);
		if(font.xft_font){
			if(!xftdraw)
				throw new Exception("error, xft drawable does not exist");
			XftDrawStringUtf8(xftdraw, &col.foreground_xft, font.xft_font, x, y, cast(char*)text, cast(int)text.length);
		}else if(font.set){
			Xutf8DrawString(dpy, canvas, font.set, gc, x, y, cast(char*)text, cast(int)text.length);
		}else{
			XSetFont(dpy, gc, font.xfont.fid);
			XDrawString(dpy, canvas, gc, x, y, cast(char*)text, cast(int)text.length);
		}
	}

	void freecol(ColorSet col){
		if(&col.foreground_xft)
			XftColorFree(dpy, DefaultVisual(dpy, DefaultScreen(dpy)), DefaultColormap(dpy, DefaultScreen(dpy)), &col.foreground_xft);
	}

	ulong getcolor(string colstr){
		Colormap cmap = DefaultColormap(dpy, DefaultScreen(dpy));
		XColor color;
		if(!XAllocNamedColor(dpy, cmap, cast(char*)colstr, &color, &color))
			throw new Exception("cannot allocate color '%s'", colstr);
		return color.pixel;
	}

	ColorSet initcolor(string  foreground, string  background){
		ColorSet col;
		col.background = getcolor(background);
		col.foreground = getcolor(foreground);
		if(font.xft_font)
			if(!XftColorAllocName(dpy, DefaultVisual(dpy, DefaultScreen(dpy)),
				DefaultColormap(dpy, DefaultScreen(dpy)), cast(char*)foreground, &col.foreground_xft))
				throw new Exception("error, cannot allocate xft font color '%s'", foreground);
		return col;
	}

	void initfont(string fontstr){
		char* def;
		char** missing, names;
		int i, n;
		XFontStruct** xfonts;
		font.xfont = XLoadQueryFont(dpy, cast(char*)fontstr);
		if(!font.xfont)
			font.set = XCreateFontSet(dpy, cast(char*)fontstr, &missing, &n, &def);
		if(!font.set)
			font.xft_font = XftFontOpenName(dpy, DefaultScreen(dpy), cast(char*)fontstr);

		if(font.xfont){
			font.ascent = font.xfont.ascent;
			font.descent = font.xfont.descent;
			font.width   = font.xfont.max_bounds.width;
		}else if(font.set){
			n = XFontsOfFontSet(font.set, &xfonts, &names);
			for(i = 0; i < n; i++){
				font.ascent  = max(font.ascent,  xfonts[i].ascent);
				font.descent = max(font.descent, xfonts[i].descent);
				font.width   = max(font.width,   cast(int)xfonts[i].max_bounds.width);
			}
		}else if(font.xft_font){
			font.ascent = font.xft_font.ascent;
			font.descent = font.xft_font.descent;
			font.width = font.xft_font.max_advance_width;
		}else
			throw new Exception("cannot load font '%s'", fontstr);
		if(missing)
			XFreeStringList(missing);
		font.height = font.ascent + font.descent;
		font.charWidth = actualWidth("A") - 3;
	}

	void mapdc(Window win, uint w, uint h){
		XCopyArea(dpy, canvas, win, gc, 0, 0, w, h, 0, 0);
	}

	void resizedc(uint w, uint h){
		int screen = DefaultScreen(dpy);
		if(canvas)
			XFreePixmap(dpy, canvas);
		w = w;
		h = h;
		canvas = XCreatePixmap(dpy, DefaultRootWindow(dpy), w, h, DefaultDepth(dpy, screen));
		if(font.xft_font && !(xftdraw)){
			xftdraw = XftDrawCreate(dpy, canvas, DefaultVisual(dpy,screen), DefaultColormap(dpy,screen));
			if(!(xftdraw))
				throw new Exception("error, cannot create xft drawable");
		}
	}

	int textWidth(string text){
		return cast(int)std.utf.count(text)*font.charWidth;
	}

	int actualWidth(string c){
		if(font.xft_font){
			XGlyphInfo gi;
			XftTextExtentsUtf8(dpy, font.xft_font, cast(char*)c, cast(int)c.length, &gi);
			return gi.width;
		}else if(font.set){
			XRectangle r;
			Xutf8TextExtents(font.set, cast(char*)c, cast(int)c.length, null, &r);
			return r.width;
		}else
			return XTextWidth(font.xfont, cast(char*)c, cast(int)c.length);
	}

}

extern(C){

	pragma(lib, "Xft");

	struct XftColor {
		ulong pixel;
		XRenderColor color;
	}
	struct XftFont {
		int ascent;
		int descent;
		int height;
		int max_advance_width;
		FcCharSet* charset;
		FcPattern* pattern;
	}
	struct XRenderColor {
		ushort   red;
	    ushort   green;
	    ushort   blue;
	    ushort   alpha;
	}

	struct XftDraw{}
	struct FcCharSet{}
	struct FcPattern{}
	void XftFontClose(Display*, XftFont*);
	void XftDrawDestroy(XftDraw*);
	void XftDrawStringUtf8(XftDraw*, XftColor*, XftFont*, int, int, char*, int);
	void XftColorFree(Display*, Visual*, Colormap, XftColor*);
	Bool XftColorAllocName (Display*, Visual*, Colormap, char*, XftColor*);
	XftFont* XftFontOpenName (Display*, int , char *);
	XftDraw *XftDrawCreate (Display*, Drawable, Visual*, Colormap);
	void XftTextExtentsUtf8(Display*, XftFont*, char*, int, XGlyphInfo*);

	struct XGlyphInfo {
	    ushort width;
	    ushort height;
	    short x;
	    short y;
	    short xOff;
	    short yOff;
	}
}
