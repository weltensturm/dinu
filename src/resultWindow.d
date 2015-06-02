module dinu.resultWindow;

import
	std.math,
	std.algorithm,
	std.datetime,
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

	double scrollCurrent = 0;
	double selectCurrent = 0;
	long lastUpdate;

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
		if(pos != [targetX, windowMain.size.y+windowMain.pos.y])
			move([targetX, windowMain.size.y+windowMain.pos.y]);

		auto cur = Clock.currSystemTick.msecs;
		auto delta = cur - lastUpdate;
		lastUpdate = cur;

		auto scrollTarget = min(max(0, cast(long)matches.length-cast(long)options.lines),
					max(0, commandBuilder.selected-options.lines/2));
		if(options.animations > 0){
			scrollCurrent = scrollCurrent.eerp(scrollTarget, delta/150.0/options.animations);
			selectCurrent = selectCurrent.eerp(commandBuilder.selected, delta/100.0/options.animations);
		}else{
			scrollCurrent = scrollTarget;
			selectCurrent = commandBuilder.selected;
		}
	}

	override void draw(){
		if(!active)
			return;
		auto padding = 0.4.em;
		dc.rect([0,0], size, options.colorBg);
		if(selectCurrent < 0 && (commandBuilder.command.length==1 || commandBuilder.commandHistory))
			dc.rect([0,0], [size.w,1.4.em], options.colorHintBg);
		dc.rect([0,cast(int)((selectCurrent-scrollCurrent)*1.4.em)], [size.w, 1.4.em], options.colorSelected);
		auto start = cast(size_t)scrollCurrent;
		foreach(int i, result; matches[start..min($, start+16)]){
			int x = padding;
			int y = cast(int)(1.4.em*(i-(scrollCurrent-start)));
			x += result.data.draw(dc, [x, y+0.2.em], start+i == commandBuilder.selected);
			auto hint = result.data.hint;
			if(hint.length){
				dc.text([max(x, size.w-dc.textWidth(hint)-0.6.em), y+0.2.em], hint, options.colorHint);
			}
		}
		int scrollbarWidth = padding;
		//dc.rect([size.w-0.2.em, 0], [0.2.em, size.h], options.colorBg);
		if(matches.length > 15){
			double scrollbarHeight = size.h/(max(1.0, (cast(long)matches.length-cast(long)14).log2));
			int scrollbarOffset = cast(int)((size.h - scrollbarHeight - 0.3.em + 1) * (scrollCurrent/(max(1.0, matches.length-15))));
			dc.rect([size.w-scrollbarWidth, scrollbarOffset], [scrollbarWidth, cast(int)scrollbarHeight], options.colorHintBg);
		}
		super.draw;
	}

}