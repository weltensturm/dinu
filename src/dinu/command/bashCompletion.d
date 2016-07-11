module dinu.command.bashCompletion;


import dinu;


__gshared:


class CommandBashCompletion: Command {

	this(string name){
		super(name);
		type = Type.bashCompletion;
	}

	override void run(){}

}
