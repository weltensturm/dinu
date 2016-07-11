module dinu.command.special;


import dinu;


__gshared:


class CommandSpecial: CommandExec {

	this(string name){
		super(name);
		this.name = name;
		type = Type.special;
		color = options.colorExec;

	}

	override void run(){
		final switch(name){
			case "cd":
				if(options.flatman){
					["flatman-context", parameter].execute;
					options.configPath = ["flatman-context", "-p"].execute.output;
					chdir(parameter.expandTilde.unixClean);
				}else{
					options.configPath.log("%s exec %s!%s!%s".format(0, Type.special, serialize.replace("!", "\\!"), parameter.replace("!", "\\!")));
					try{
						chdir(parameter.expandTilde.unixClean);
						std.file.write(options.configPath, getcwd);
						options.configPath.log("%s exit %s".format(0, 0));
					}catch(Exception e){
						writeln(e);
						options.configPath.log("%s exit %s".format(0, 1));
					}
				}
				break;
			case "clear":
				commandBuilder.clearOutput;
				break;
			case ".":
				this.spawnCommand("xdg-open .", "");
				break;
		}
	}

}