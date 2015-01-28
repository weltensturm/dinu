module desktop;


import
	std.file,
	std.path,
	std.string;


const string[] desktopPaths = [
	"/usr/share/applications/",
	"~/.local/share/applications/"
];


class DesktopEntry {

	string exec;
	string type;
	string name;
	string comment;
	string terminal;

	this(string path){
		if(!path.isFile)
			return;
		foreach(line; path.readText.splitLines){
			if(line.startsWith("Exec="))
				exec = line.chompPrefix("Exec=");
			if(line.startsWith("Name="))
				name = line.chompPrefix("Name=");
		}
	}

}


DesktopEntry[] getAll(){
	DesktopEntry[] result;
	foreach(path; desktopPaths){
		foreach(entry; path.expandTilde.dirEntries(SpanMode.shallow))
			result ~= new DesktopEntry(entry);
	}
	return result;
}


