module dinu.resultWindow;

import
	std.math,
	std.algorithm,
	dinu.dinu,
	dinu.util,
	dinu.window,
	dinu.xclient,
	dinu.commandBuilder,
	dinu.command,
	dinu.filter,
	draw;



class ResultWindow: Window {

	FuzzyFilter!(Command).Match[] matches;

	this(){
		super(options.screen, [500,500], [1.4.em*15,500]);
		dc.initfont(options.font);
	}

	void update(XClient windowMain){
		if(!runProgram){
			destroy;
			return;
		}
		matches = choiceFilter.res;
		if(!matches.length && active)
			hide;
		else if(matches.length && !active)
			show;
		if(!active)
			return;
		auto targetHeight = min(15, matches.length)*1.4.em+0.3.em;
		if(targetHeight != size.h)
			resize([size.w, targetHeight]);
		auto targetX = windowMain.size.w/4;
		if(!commandBuilder.commandHistory)
			targetX += dc.textWidth(commandBuilder.finishedPart);
		if(pos != [targetX, windowMain.size.y+options.y])
			move([targetX, windowMain.size.y+options.y]);
	}

	override void draw(){
		if(!active)
			return;
		auto padding = 0.4.em;
		dc.rect([0,0], size, options.colorBg);
		size_t start = cast(size_t)min(max(0, cast(long)matches.length-15), max(0, commandBuilder.selected+1-16/2));
		foreach(int i, result; matches[start..min($, start+15)]){
			int x = padding;
			if(start+i == commandBuilder.selected)
				dc.rect([0,1.4.em*i], [size.w, 1.4.em], options.colorSelected);
			else if(start+i == 0 && commandBuilder.selected==-1 && commandBuilder.command.length==1)
				dc.rect([0,1.4.em*i], [size.w,1.4.em], options.colorHintBg);
			x += result.data.draw(dc, [x, 1.4.em*i+0.2.em], start+i == commandBuilder.selected);
			auto hint = result.data.hint;
			if(hint.length){
				dc.text([max(x, size.w-dc.textWidth(hint)-0.6.em), 1.4.em*i+0.2.em], hint, options.colorHint);
			}
		}
		int scrollbarWidth = padding;
		//dc.rect([size.w-0.2.em, 0], [0.2.em, size.h], options.colorBg);
		if(matches.length > 15){
			double scrollbarHeight = size.h/(max(1.0, (cast(long)matches.length-cast(long)14).log2));
			int scrollbarOffset = cast(int)((size.h - scrollbarHeight - 0.3.em + 1) * (start/(max(1.0, matches.length-15))));
			dc.rect([size.w-scrollbarWidth, scrollbarOffset], [scrollbarWidth, cast(int)scrollbarHeight], options.colorHintBg);
		}
		super.draw;
	}

}