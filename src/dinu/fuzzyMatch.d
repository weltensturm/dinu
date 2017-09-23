module dinu.fuzzyMatch;

import dinu;



/// Returns [Score, IndexMatch...]
int[] compareFuzzy(string haystack, string needle){
	if(!needle.length)
		return [1];

	int[][] matches = [[]];
	foreach(i, c; haystack){
	    foreach(m; matches){
	        if(m.length < needle.length && c.toLower == needle[m.length].toLower){
	        	matches ~= (m ~ [i.to!int]);
	        }
	    }
    }

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

