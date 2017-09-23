module dinu.loader.windows;

import dinu;


__gshared:


class WindowsLoader: ChoiceLoader {

	override void run(){
		/+
		auto p = pipeShell("xwininfo -root -children", Redirect.stdout);
		foreach(line; p.stdout.byLine){
			auto r = line.matchFirst(`0x((?:[0-9]|[a-f])+) "([^"]*)"`);
			if(!r.empty){
				add(new CommandWindow([r[1].to!string, r[2].to!string].bangJoin));
			}
		}
		scope(exit)
			p.pid.kill;
		+/
		/+

		import ws.wm;
		x11.X.Window root_return, parent_return;
		x11.X.Window* children;
		uint nchildren;
		XGrabServer(wm.displayHandle);
		XQueryTree(wm.displayHandle, root, &root_return, &parent_return, &children, &nchildren);
		if(children){
			foreach(window; children[0..nchildren]){
				if(root == root_return){
					auto w = new ws.wm.Window(window);
					if(!w.getTitle.length)
						continue;
					add(new CommandWindow(["%#x".format(w.windowHandle), w.getTitle].bangJoin));
				}
			}
			XFree(children);
		}
		XUngrabServer(wm.displayHandle);
		+/
	}

}

