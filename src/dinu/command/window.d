module dinu.command.window;


import dinu;

__gshared:


shared immutable class CommandWindow: Command {

    string id;

    this(string args){
        id = args.bangSplit[0];
        super(Type.window, name, options.colorWindow);
    }

	override size_t score(){
		return 12;
	}

    override void run(string){
        executeShell("wmctrl -a " ~ id);
    }

}
