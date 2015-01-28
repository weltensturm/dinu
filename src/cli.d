module cli;


mixin template cli(T){

	import
		std.stdio,
		std.string,
		std.conv;

	this(string[] args){
		foreach(member; __traits(allMembers, T)) {
			foreach(attr; __traits(getAttributes, mixin(member))){
				foreach(i, arg; args){
					if(arg[0] == '-' && arg == attr){
						static if(is(typeof(mixin(member)) == bool)){
							mixin(member ~ " = ! " ~ member ~ ";");
							continue;
						}else{
							mixin(member ~ " = to!(typeof(" ~ member ~ "))(args[i+1]);");
							continue;
						}
					}
				}
			}
		}
	}

	void usage(){
		writeln("options: ");
		foreach(member; __traits(allMembers, T))
			foreach(attr; __traits(getAttributes, mixin(member)))
				writeln("\t[%s (%s %s)]".format(attr, mixin("typeof(" ~ member ~ ").stringof"), member));
	}

}
