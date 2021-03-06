module dinu.draw;

import dinu;


__gshared:


string tabsToSpaces(string text, int spaces=4){
	string result;
	int i = 0;
	foreach(c; text){
		if(c == '\t'){
			foreach(si; 0..spaces-(i%spaces))
				result ~= ' ';
			i += 4;
		}else{
			result ~= c;
			i += 1;
		}
	}
	return result;
}

float[3] color(string text){
	return [
		text[1..3].to!int(16)/255.0,
		text[3..5].to!int(16)/255.0,
		text[5..7].to!int(16)/255.0
	];
}