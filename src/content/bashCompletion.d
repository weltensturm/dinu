module dinu.content.bashCompletion;


import
	dinu.content.content,
	dinu.command;


__gshared:


class BashCompletionLoader: ChoiceLoader {

	override void run(){

	}

}


class CommandBashCompletion: Command {

	this(string name){
		super(name);
		type = Type.bashCompletion;
	}

	override void run(){}

}
