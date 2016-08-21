module dinu.filter;

import
	core.thread,
	std.conv,
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
		int[] positions;
		T data;
	}

	protected {

		T[] choices;
		Match[] matches;
		string filter;
		string narrowQueue;

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
			auto res = p.filterText.compareFuzzy(filter);
			match.score = res[0];
			match.positions = res[1..$];
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



int[][] allMatches(string haystack, string needle, int start=0){
	if(!needle.length)
		return [[]];
	int[][] matches = [];
	foreach(hi, h; haystack[start..$]){
		if(needle[0].toLower == h.toLower){
			foreach(m; haystack.allMatches(needle[1..$], start+hi.to!int)){
				if(!m.length && needle.length == 1 || m.length == needle.length-1)
					matches ~= ([start+hi.to!int] ~ m);
			}
		}
	}
	return matches;
}


int[] compareFuzzy(string haystack, string needle){
	if(!needle.length)
		return [1];
	auto matches = haystack.allMatches(needle);
	int best = -1;
	long bestScore;
	foreach(i, m; matches){
		if(m.length < needle.length)
			continue;
		auto s = m.score;
		if(s > bestScore){
			bestScore = s;
			best = i.to!int;
		}
	}
	if(best < 0)
		return [0];
	return [bestScore.to!int] ~ matches[best];
}


long score(int[] match){
	if(match.length == 1)
		return 1;
	long s = 0;
	int previous = -1;
	int offset = 0;
	foreach(m; match){
		if(previous == -1){
			previous = m;
			offset = m;
			continue;
		}
		if(m == previous+1){
			s += 1000;
		}
		previous = m;
	}
	/+
	if(!s)
		return 0;
	+/
	return 1.max(s-offset);
}



unittest {
	assert("1".compareFuzzy("1")[0] > 0);
	assert("122".compareFuzzy("123")[0] <= 0);
	assert("33453".compareFuzzy("345")[0] > 0);
	assert(
		"33453".compareFuzzy("345")[0] ==
		"23453".compareFuzzy("345")[0]
	);
	assert(
		"32453".compareFuzzy("345")[0] <
		"23453".compareFuzzy("345")[0]
	);
	assert("ls".compareFuzzy("ls")[0] > 0);
}

