module dinu.cli;


import
	std.conv,
	std.stdio,
	std.string;



void fill(T)(ref T object, string[] args){
	try{
		foreach(member; __traits(allMembers, T)) {
			foreach(attr; __traits(getAttributes, mixin("object."~member))){
				foreach(i, arg; args){
					if(arg[0] == '-' && arg == attr){
						static if(is(typeof(mixin("object."~member)) == bool)){
							mixin("object." ~ member ~ " = !object." ~ member ~ ";");
							continue;
						}else{
							mixin("object." ~ member ~ " = to!(typeof(T." ~ member ~ "))(args[i+1]);");
							continue;
						}
					}
				}
			}
		}
	}catch(Throwable t){
		usage(object);
		throw t;
	}
}

void usage(T)(T object){
	writeln("options: ");
	foreach(member; __traits(allMembers, T))
		foreach(attr; __traits(getAttributes, mixin("object."~member)))
			writeln("\t%s: %s %s".format(attr, mixin("typeof(object." ~ member ~ ").stringof"), member));
}
