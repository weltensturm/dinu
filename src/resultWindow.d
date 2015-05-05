module dinu.resultWindow;

import
	std.math,
	std.algorithm,
	dinu.dinu,
	dinu.xapp,
	dinu.window,
	dinu.xclient,
	dinu.launcher,
	draw;



class ResultWindow: Window {

	//Arguments options;
	int offset;
	ChoiceFilter.Match[] matches;

	this(){
		super(options.screen, [500,500], [500,500]);
		//this.options = options;
		offset = pos[0];
		dc.initfont(options.font);
	}

	void update(XClient windowMain){
		matches = choiceFilter.res;
		if(!matches.length && active)
			hide;
		else if(matches.length && !active)
			show;
		if(!active)
			return;
		if(min(15, matches.length)*1.em != size.h)
			resize([size.w, 1.4.em*min(15, matches.length)+0.3.em]);
		if(pos[0] != offset+dc.textWidth(launcher.finishedPart)-0.2.em || pos[1] != windowMain.size.y)
			move([windowMain.size.w/4+dc.textWidth(launcher.finishedPart)-0.2.em, windowMain.size.y]);
	}

	override void draw(){
		if(!active)
			return;
		dc.rect([0,0], size, options.colorBg);
		size_t start = cast(size_t)min(max(0, cast(long)matches.length-15), max(0, launcher.selected+1-16/2));
		foreach(int i, result; matches[start..min($, start+15)]){
			if(start+i == launcher.selected)
				dc.rect([0.2.em,1.4.em*i], [size.w-0.5.em, 1.4.em], options.colorSelected);
			else if(start+i == 0 && launcher.selected==-1 && !launcher.params.length && launcher.command.text.length)
				dc.rect([0.2.em,1.4.em*i], [size.w-0.5.em,1.4.em], options.colorHintBg);
			result.data.draw(dc, [0.4.em, 1.4.em*i+0.95.em], start+i == launcher.selected);
		}
		int scrollbarWidth = 0.5.em;
		dc.rect([size.w-0.3.em, 0], [0.3.em, size.h], options.colorBg);
		if(matches.length > 15){
			double scrollbarHeight = size.h/(max(1.0, (cast(long)matches.length-cast(long)14).log2));
			int scrollbarOffset = cast(int)((size.h - scrollbarHeight - 0.2.em) * (start/(max(1.0, matches.length-15))));
			dc.rect([size.w-scrollbarWidth, scrollbarOffset], [scrollbarWidth, cast(int)scrollbarHeight], options.colorHintBg);
		}
		super.draw;
	}

}