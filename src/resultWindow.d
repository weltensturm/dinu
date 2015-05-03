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

	Arguments config;
	int offset;

	this(XApp wm, int[2] pos, int[2] size, Arguments config){
		super(wm, pos, size);
		this.config = config;
		offset = pos[0];
		dc.initfont(config.font);
	}

	override void draw(){
		auto matches = choiceFilter.res;

		int eh = 1.4.em;

		if(min(15, matches.length)*em(1) != size[1])
			resize([size[0], eh*min(15, matches.length)+0.3.em]);

		if(pos[0] != offset+dc.textWidth(launcher.finishedPart)-0.2.em || pos[1] != client.size.y)
			move([offset+dc.textWidth(launcher.finishedPart)-0.2.em, client.size.y]);

		if(!matches.length && active)
			hide;
		else if(matches.length && !active)
			show;

		dc.rect([0,0], size, dc.color(config.colorBg));

		size_t start = cast(size_t)min(max(0, cast(long)matches.length-15), max(0, launcher.selected+1-16/2));

		foreach(int i, result; matches[start..min($, start+15)]){
			if(start+i == launcher.selected)
				dc.rect([0.2.em,eh*i], [size[0]-0.5.em, eh], dc.color(config.colorSelected));
			else if(start+i == 0 && launcher.selected==-1 && !launcher.params.length && launcher.command.text.length)
				dc.rect([0.2.em,eh*i], [size[0]-0.5.em,eh], colorOutputBg);
			//dc.text([em(0.4),em(1.4*i+1)], result.data.text, dc.fontColor(config.colorText));
			result.data.draw(dc, [0.4.em, eh*i+0.95.em], start+i == launcher.selected);
		}

		int scrollbarWidth = 0.5.em;
		dc.rect([size[0]-0.3.em, 0], [0.3.em, size[1]], colorBg);
		if(matches.length > 15){
			double scrollbarHeight = size.h/(max(1.0, (cast(long)matches.length-cast(long)14).log2));
			int scrollbarOffset = cast(int)((size.h - scrollbarHeight - 0.2.em) * (start/(max(1.0, matches.length-15))));
			dc.rect([size[0]-scrollbarWidth, scrollbarOffset], [scrollbarWidth, cast(int)scrollbarHeight], colorOutputBg);
		}

		dc.mapdc(handle, size[0], size[1]);
	}

}