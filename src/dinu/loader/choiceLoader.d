module dinu.loader.choiceLoader;


import dinu;


__gshared:


class ChoiceLoader {

	protected {
		immutable(Command)[] loaded;
		void delegate(immutable Command) dg;
		bool active = true;
	}

	this(){
		task({
			try
				run;
			catch(Exception e)
				writeln(e);
		}).executeInNewThread;
	}

	void each(void delegate(immutable Command) dg){
		synchronized(this){
			if(!active)
				return;
			foreach(c; loaded)
				dg(c);
			this.dg = dg;
		}
	}

	void eachComplete(void delegate(immutable Command) dg){
		synchronized(this){
			foreach(c; loaded)
				dg(c);
		}
	}

	void add(immutable Command c){
		synchronized(this){
			if(!active)
				return;
			loaded ~= c;
			if(dg)
				dg(c);
		}
	}

	void run(){
	}

	void stop(){
		synchronized(this){
			if(!active)
				return;
			active = false;
		}
	}

}

