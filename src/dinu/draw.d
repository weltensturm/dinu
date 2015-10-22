module dinu.draw;

import
	std.string,
	std.utf,
	std.algorithm,
	std.conv,
	x11.X,
	x11.Xlib,
	x11.Xutil,
	x11.extensions.Xrender,
	x11.keysymdef,
	ws.bindings.xft,
	dinu.util,
	dinu.xclient;


__gshared:


alias Color = size_t;


struct FontColor {
	Color id;
	XftColor id_xft;
	alias id this;
}

struct Font {
	string name;
	int ascent;
	int descent;
	int height;
	int width;
	XFontSet set;
	XFontStruct *xfont;
	XftFont *xft_font;
}

string tabsToSpaces(string text, int spaces=4){
	string result;
	int i = 0;
	foreach(c; text){
		if(c == '\t'){
			foreach(si; 0..spaces-(i%spaces))
				result ~= ' ';
			i += 4;
		}else{
			result ~= c;
			i += 1;
		}
	}
	return result;
}


class DrawingContext {

	Bool invert;
	Display* dpy;
	GC gc;
	Pixmap canvas;
	XftDraw* xftdraw;
	Font font;
	Color[string] colors;
	FontColor[string] fontColors;

	this(){
		dpy = XOpenDisplay(null);
		if(!dpy)
			throw new Exception("cannot open display");
		gc = XCreateGC(dpy, DefaultRootWindow(dpy), 0, null);
		XSetLineAttributes(dpy, gc, 1, LineSolid, CapButt, JoinMiter);
	}

	void destroy(){
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

		foreach(c; fontColors)
			XftColorFree(dpy, DefaultVisual(dpy, DefaultScreen(dpy)), DefaultColormap(dpy, DefaultScreen(dpy)), &c.id_xft);

	}

	void rect(int[2] pos, int[2] size, string col, bool fill=true){
		auto color = this.color(col);
		XSetForeground(dpy, gc, color);
		if(fill)
			XFillRectangle(dpy, canvas, gc, pos[0], pos[1], size[0], size[1]);
		else
			XDrawRectangle(dpy, canvas, gc, pos[0], pos[1], size[0]-1, size[1]-1);
	}

	void clip(int[2] pos, int[2] size){
		auto rect = XRectangle(cast(short)pos[0], cast(short)pos[1], cast(short)size[0], cast(short)size[1]);
		XftDrawSetClipRectangles(xftdraw, 0, 0, &rect, 1);
		XSetClipRectangles(dpy, gc, 0, 0, &rect, 1, Unsorted);
	}

	void noclip(){
		XSetClipMask(dpy, gc, None);
		XftDrawSetClip(xftdraw, null);
	}

	int text(int[2] pos, string text, string col, double offset=0){
		text = text.tabsToSpaces;
		auto color = this.fontColor(col);
		int textWidth = textWidth(text);
		int offsetRight = max(0.0,-offset).em;
		int offsetLeft = max(0.0,offset-1).em;
		int x = pos[0] - cast(int)(min(1,max(0,offset))*textWidth) + offsetRight - offsetLeft;
		int y = pos[1] + font.height-1;
		XSetForeground(dpy, gc, color.id);
		if(font.xft_font){
			if(!xftdraw)
				throw new Exception("error, xft drawable does not exist");
			XftDrawStringUtf8(xftdraw, &color.id_xft, font.xft_font, x, y, cast(char*)text, cast(int)text.length);
		}else if(font.set){
			Xutf8DrawString(dpy, canvas, font.set, gc, x, y, cast(char*)text, cast(int)text.length);
		}else{
			XSetFont(dpy, gc, font.xfont.fid);
			XDrawString(dpy, canvas, gc, x, y, cast(char*)text, cast(int)text.length);
		}
		return x+textWidth-pos[0];
	}

	Color color(string colstr){
		if(colstr in colors)
			return colors[colstr];
		Colormap cmap = DefaultColormap(dpy, DefaultScreen(dpy));
		XColor c;
		if(!XAllocNamedColor(dpy, cmap, cast(char*)colstr, &c, &c))
			throw new Exception("cannot allocate color '%s'".format(colstr));
		return c.pixel;
	}

	FontColor fontColor(string name){
		if(name in fontColors)
			return fontColors[name];
		FontColor col;
		col.id = color(name);
		if(font.xft_font)
			if(!XftColorAllocName(dpy, DefaultVisual(dpy, DefaultScreen(dpy)),
				DefaultColormap(dpy, DefaultScreen(dpy)), cast(char*)name, &col.id_xft)
				)
				throw new Exception("error, cannot allocate xft font color '%s'".format(name));
		return col;
	}

	void initfont(string fontstr){
		foreach(c; fontColors)
			XftColorFree(dpy, DefaultVisual(dpy, DefaultScreen(dpy)), DefaultColormap(dpy, DefaultScreen(dpy)), &c.id_xft);
		fontColors = fontColors.init;
		char* def;
		char** missing, names;
		font.name = fontstr;
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
			int screen = DefaultScreen(dpy);
			xftdraw = XftDrawCreate(dpy, canvas, DefaultVisual(dpy,screen), DefaultColormap(dpy,screen));
			font.ascent = font.xft_font.ascent;
			font.descent = font.xft_font.descent;
			font.width = font.xft_font.max_advance_width;
		}else
			throw new Exception("cannot load font '%s'".format(fontstr));
		if(missing)
			XFreeStringList(missing);
		font.height = font.ascent + font.descent;
	}

	void map(Window win, int[2] size){
		XCopyArea(dpy, canvas, win, gc, 0, 0, size.w, size.h, 0, 0);
	}

	void resize(int[2] size){
		int screen = DefaultScreen(dpy);
		if(canvas)
			XFreePixmap(dpy, canvas);
		canvas = XCreatePixmap(dpy, DefaultRootWindow(dpy), size.w, size.h, DefaultDepth(dpy, screen));
		if(xftdraw)
			XftDrawChange(xftdraw, canvas);
	}

	int textWidth(string c){
		c = c.tabsToSpaces;
		if(font.xft_font){
			XGlyphInfo gi;
			XftTextExtentsUtf8(dpy, font.xft_font, cast(char*)c, cast(int)c.length, &gi);
			return gi.xOff;
		}else if(font.set){
			XRectangle r;
			Xutf8TextExtents(font.set, cast(char*)c, cast(int)c.length, null, &r);
			return r.width;
		}else
			return XTextWidth(font.xfont, cast(char*)c, cast(int)c.length);
	}

}
