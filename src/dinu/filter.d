module dinu.filter;

import
	core.thread,
	std.parallelism,
	std.string,
	std.path,
	std.stdio,
	std.algorithm,
	std.uni,
	std.datetime;


__gshared:


class FuzzyFilter(T) {

	struct Match {
		long score;
		T data;
	}

	protected {

		T[] choices;
		Match[] matches;
		string filter;
		string narrowQueue;
		void delegate() waitLoad;

		Thread filterThread;
		bool restart;
		bool idle = true;

		bool delegate(T) filterFunc;

	}

	this(bool delegate(T) filterFunc){
		this.filterFunc = filterFunc;
		filterThread = new Thread(&filterLoop);
		filterThread.start;
	}

	void reset(string filter=""){
		filter = filter.expandTilde;
		restart = true;
		synchronized(this){
			narrowQueue = "";
			this.filter = filter;
		}
	}

	void narrow(string text){
		synchronized(this)
			narrowQueue ~= text;
	}

	Match[] res(){
		return matches;
	}

	void add(T p){
		synchronized(this)
			choices ~= p;
		tryMatch(p);
	}

	void set(T[] choices){
		synchronized(this){
			this.choices = choices;
			reset;
		}
	}

	void remove(T[] choices){
		if(!choices.length)
			return;
		synchronized(this){
			auto old = this.choices;
			this.choices = [];
			foreach(o; old)
				if(!choices.canFind(o))
					this.choices ~= o;
		}
	}

	protected {

		void tryMatch(T p){
			if(!filterFunc(p))
				return;
			Match match;
			match.score = p.filterText.cmpFuzzy(filter);
			if(match.score > 0){
				match.score += p.score;
				match.data = p;
				synchronized(this){
					foreach(i, e; matches){
						if(restart)
							break;
						if(e.score <= match.score){
							if(e.score == match.score && e.data.filterText.icmp(match.data.filterText) < 0)
								continue;
							matches = matches[0..i] ~ match ~ matches[i..$];
							return;
						}
					}
					matches ~= match;
				}
			}
		}

		void intReset(string filter){
			T[] cpy;
			synchronized(this){
				if(!idle)
					throw new Exception("already working");
				idle = false;
				this.filter = filter;
				matches = [];
				cpy = choices.dup;
			}
			foreach(m; cpy){
				tryMatch(m);
				if(restart)
					break;
			}
			synchronized(this)
				idle = true;
		}

		void intNarrow(string filter){
			Match[] cpy;
			synchronized(this){
				if(!idle)
					throw new Exception("already working");
				idle = false;
				this.filter = filter;
				cpy = matches;
				matches = [];
			}
			foreach(m; cpy){
				tryMatch(m.data);
				if(restart)
					break;
			}
			synchronized(this)
				idle = true;
		}

		void filterLoop(){
			filterThread.isDaemon = true;
			try{
				while(true){
					if(narrowQueue.length){
						synchronized(this){
							filter ~= narrowQueue;
							narrowQueue = "";
						}
						intNarrow(filter);
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


long cmpFuzzy(string str, string sub){
	long scoreMul = 100;
	long score = scoreMul*10;
	size_t curIdx;
	long largestScore;
	foreach(i, c; str){
		if(curIdx<sub.length && c.toLower == sub[curIdx].toLower){
			scoreMul *= (c == sub[curIdx] ? 4 : 3);
			score += scoreMul;
			curIdx++;
		}else{
			scoreMul = 100;
		}
		if(curIdx==sub.length){
			scoreMul = 100;
			curIdx = 0;
			score = scoreMul*10;
			if(largestScore < score-i+sub.length)
				largestScore = score-i+sub.length;
		}
	}
	if(!largestScore)
		return 0;
	if(!sub.startsWith(".") && (str.canFind("/.") || str.startsWith(".")))
		largestScore -= 5;
	if(sub == str)
		largestScore += 10000000;
	return largestScore;
}

