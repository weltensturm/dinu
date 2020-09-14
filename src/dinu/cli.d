module dinu.cli;


import
	std.conv,
	std.stdio,
	std.string,
	dinu.draw;



void fill(T)(ref T object, string[] args){
	void delegate(string)[string] setters;
	void delegate()[string] settersBool;
	foreach(member; __traits(allMembers, T)) {
		foreach(attr; __traits(getAttributes, mixin("object."~member))){
			static if(is(typeof(mixin("object."~member)) == bool)){
				settersBool[attr] = (){ mixin("object." ~ member ~ " = !object." ~ member ~ ";"); };
				if(member != "-" ~ attr)
					settersBool["--" ~ member] = settersBool[attr];
			}else{
				static if(is(typeof(mixin("object."~member)) == float[4]))
					setters[attr] = (string s){ mixin("object." ~ member ~ " = s.color;"); };
				else
					setters[attr] = (string s){ mixin("object." ~ member ~ " = s.to!(typeof(T." ~ member ~ "));"); };
				if(member != "-" ~ attr)
					setters["--" ~ member] = setters[attr];
			}
		}
	}
	void delegate(string) nextSetter;
	string nextParamName;
	try {
		foreach(arg; args[1..$]){
			try {
				if(nextSetter){
					nextSetter(arg);
					nextSetter = null;
				}else if(arg in settersBool){
					settersBool[arg]();
				}else if(arg in setters){
					nextSetter = setters[arg];
					nextParamName = arg;
				}else{
					throw new Exception ("Unknown argument");
				}
			}catch(Exception e){
				throw new Exception("Error in \"" ~ (nextSetter ? nextParamName ~ " " ~ arg : arg) ~ "\": " ~ e.msg);
			}
		}
		if(nextSetter)
			throw new Exception("Missing parameter to argument \"" ~ nextParamName ~ "\"");
	}catch(Throwable e){
		usage(object);
		throw e;
	}
}

void usage(T)(T object){
	writeln("options: ");
	foreach(member; __traits(allMembers, T))
		foreach(attr; __traits(getAttributes, mixin("object."~member))){
			if(attr == "-" ~ member)
				writeln("\t%s: %s".format(attr, mixin("typeof(object." ~ member ~ ").stringof")));
			else
				writeln("\t%s --%s: %s".format(attr, member, mixin("typeof(object." ~ member ~ ").stringof")));
		}
}
