module dinu.filter;

import
	core.thread,
	core.atomic,
	std.conv,
	std.parallelism,
	std.string,
	std.path,
	std.stdio,
	std.algorithm,
	std.range,
	std.uni,
	std.datetime,
	dinu.fuzzyMatch;


shared struct Match(T) {
	long score;
	immutable(int)[] positions;
	immutable(T)[] data;
}


shared class Queue(T) {

	private T[] queue;

	synchronized void opOpAssign(string op)(T object) if(op == "~") {
		queue ~= object;
	}

	synchronized size_t length(){
		return queue.length;
	}

	synchronized T pop(){
		assert(queue.length, "Please check queue length, is 0");
		auto first = queue[0];
		queue = queue[1..$];
		return first;
	}

	synchronized shared(T[]) consume(){
		auto copy = queue;
		queue = [];
		return copy;
	}

}


class FuzzyFilter(T) {

	protected immutable(Match!T)[] matches;

	this(shared bool delegate(immutable T) filterFunc){
		addQueue = new shared Queue!(immutable T);
		narrowQueue = new shared Queue!string;
		this.filterFunc = filterFunc;
		auto worker = task({
			filterLoop;
		});
		worker.executeInNewThread;
	}

	void reset(string filter=""){
		filter = filter.expandTilde;
		restart = true;
		synchronized(this){
			narrowQueue.consume;
			this.filter = filter;
		}
	}

	void narrow(string text){
		narrowQueue ~= text;
	}

	immutable(Match!T)[] res(){
		return matches;
	}

	void add(immutable T p){
		synchronized(this)
			choices ~= p;
		addQueue ~= p;
	}

	void set(immutable T[] choices){
		synchronized(this)
			this.choices = choices;
		reset;
	}

	void remove(immutable T[] remove){
		if(!remove.length)
			return;
		synchronized(this)
			choices = choices.filter!(a => !remove.canFind(a)).array;
		reset;
	}

	void stop(){
		running = false;
	}

	protected {

		shared immutable(T)[] choices;
		shared Queue!(immutable T) addQueue;
		shared Queue!string narrowQueue;
		shared string filter;

		shared bool restart;

		shared bool delegate(immutable T) filterFunc;

		shared bool running = true;


		void match(immutable T p){
			if(!filterFunc(p))
				return;
			Match!T match;
			if(p.filterText == filter){
				match.score = 9999999;
				match.positions = filter.length.iota.array.to!(int[]).idup;	
			}else{
				auto res = p.filterText.compareFuzzy(p.prepFilter(filter));	
				match.score = res[0];
				match.positions = res[1..$].idup;
			}
			if(match.score > 0){
				if(!filter.startsWith(".") && (p.filterText.startsWith(".") || p.filterText.canFind("/."))){
					match.score = 1.min(match.score-100);
				}
				match.score.atomicOp!"+="(p.score);
				match.data = [p];
				foreach(i, e; matches){
					if(restart)
						break;
					if(e.score <= match.score){
						if(e.score == match.score && e.data[0].filterText.icmp(match.data[0].filterText) < 0)
							continue;
						matches = matches[0..i] ~ match ~ matches[i..$];
						return;
					}
				}
				matches ~= match;
			}
		}

		void intReset(string filter){
			this.filter = filter;
			matches = [];
			foreach(m; choices){
				match(m);
				if(restart)
					break;
			}
		}

		void intNarrow(string filter){
			this.filter = filter;
			auto cpy = matches;
			matches = [];
			foreach(m; cpy){
				match(m.data[0]);
				if(restart)
					break;
			}
		}

		void filterLoop(){
			try{
				while(running){
					if(narrowQueue.length){
						filter ~= narrowQueue.consume.join("");
						intNarrow(filter);
					}else if(addQueue.length){
						foreach(m; addQueue.consume)
							match(m);
					}else if(restart){
						restart = false;
						intReset(filter);
					}else{
						Thread.sleep(5.msecs);
					}
				}
			}catch(Throwable t)
				writeln(t);
		}

	}

}
