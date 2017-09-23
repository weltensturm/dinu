module dinu.command.bashCompletion;


import dinu;


__gshared:


shared immutable class CommandBashCompletion: Command {

	this(string name){
		super(Type.bashCompletion, name);
	}

	override void run(string){}

}
