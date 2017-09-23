module dinu.resultWindow;


import dinu;


__gshared:


class ResultWindow: ws.wm.Window {

	immutable(Match!Command)[] matches;

	double scrollCurrent = 0;
	double selectCurrent = 0;
	long lastUpdate;

	this(){
		super(1.4.em*15, 500, "dinu results", true);
		draw.setFont(options.font, 14);
	}

	void update(WindowMain windowMain){
		matches = commandBuilder.results;
		if(!matches.length && !hidden)
			hide;
		else if(matches.length && hidden)
			show;
		if(hidden)
			return;
		auto targetHeight = min(15, matches.length)*1.4.em+0.3.em;
		int targetWidth;
		foreach(match; matches){
			if(targetWidth < draw.width(match.data[0].filterText)+16)
				targetWidth = draw.width(match.data[0].filterText)+16;
		}
		auto sep = (windowMain.size.w*options.ratio).to!int;
		if(targetHeight != size.h || targetWidth != size.w)
			resize([targetWidth.min(windowMain.size.w-sep*2).to!int.max(1), targetHeight.max(1)]);
		auto targetX = windowMain.pos.x+(windowMain.size.w*options.ratio).to!int;
		targetX += draw.width(commandBuilder.finishedPart);
		if(pos != [targetX, windowMain.size.y+windowMain.pos.y])
			move([targetX, windowMain.size.y+windowMain.pos.y]);

		auto cur = (now*1000).lround;
		auto delta = cur - lastUpdate;
		lastUpdate = cur;

		auto scrollTarget = min(max(0, cast(long)matches.length-15),
								max(0, commandBuilder.selected-15/2));
		if(options.animations > 0){
			scrollCurrent = scrollCurrent.eerp(scrollTarget, delta/150.0/options.animations);
			selectCurrent = selectCurrent.eerp(commandBuilder.selected, delta/100.0/options.animations);
		}else{
			scrollCurrent = scrollTarget;
			selectCurrent = commandBuilder.selected;
		}
	}

	override void onDraw(){
		if(hidden)
			return;
		auto padding = 0.4.em;
		auto entryHeight = 1.4.em;
		auto textOffset = ((entryHeight - draw.to!XDraw.font.h)/2.0).lround.to!int;
		draw.setColor(options.colorBg);
		draw.rect([0,0], size);
		if(selectCurrent < 0 && (commandBuilder.command.length==1)){
			draw.setColor(options.colorHintBg);
			draw.rect([0,size.h-entryHeight], [size.w,entryHeight]);
		}
		draw.setColor(options.colorSelected);
		draw.rect([0,cast(int)(size.h - (selectCurrent-scrollCurrent)*entryHeight)-entryHeight], [size.w, entryHeight]);
		auto start = cast(size_t)scrollCurrent;
		foreach(int i, result; matches[start.min($-1).max(0)..min($, start+16)]){
			int x = padding;
			int y = cast(int)(size.h - entryHeight*(i-(scrollCurrent-start)) - entryHeight);
			x += result.data[0].draw(draw.to!XDraw, [x, y+textOffset], start+i == commandBuilder.selected, result.positions);
			auto hint = result.data[0].hint;
			debug(Score){
				hint = result.score.to!string;
			}
			if(hint.length){
				draw.setColor(options.colorHint);
				draw.text([max(x, size.w-draw.width(hint)-1.4.em), y+textOffset], hint);
			}
		}
		int scrollbarWidth = padding;
		draw.setColor(options.colorBg);
		//draw.rect([size.w-0.2.em, 0], [0.2.em, size.h]);
		if(matches.length > 15){
			double scrollbarHeight = size.h/(max(1.0, (cast(long)matches.length-cast(long)14).log2));
			int scrollbarOffset = cast(int)((size.h - scrollbarHeight - 0.3.em + 1) * (scrollCurrent/(max(1.0, matches.length-15))));
			draw.setColor(options.colorHintBg);
			draw.rect([size.w-scrollbarWidth, size.h-scrollbarOffset-scrollbarHeight.to!int], [scrollbarWidth, cast(int)scrollbarHeight]);
		}
		super.onDraw;
	}

}