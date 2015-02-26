module desktop;


import
	std.file,
	std.algorithm,
	std.path,
	std.regex,
	std.stdio,
	std.string;


const string[] desktopPaths = [
	"/usr",
	"/usr/local",
	"~/.local"
];


class DesktopEntry {

	string exec;
	string type;
	string name;
	string comment;
	string terminal;

	this(string text){
		foreach(line; text.splitLines){
			if(line.startsWith("Exec="))
				exec = line.chompPrefix("Exec=");
			if(line.startsWith("Name="))
				name = line.chompPrefix("Name=");
		}
	}

}

DesktopEntry[] readDesktop(string path){
	DesktopEntry[] result;
	if(!path.isFile)
		return result;
	foreach(section; matchAll(path.readText, `\[[^\]\r\n]+\](?:\r?\n(?:[^\[\r\n].*)?)*`)){
		result ~= new DesktopEntry(section.hit);
	}
	return result;
}

DesktopEntry[] getAll(){
	DesktopEntry[] result;
	foreach(path; desktopPaths){
		if((path.expandTilde~"/share/applications").exists)
			foreach(entry; (path.expandTilde~"/share/applications").dirEntries(SpanMode.breadth))
				result ~= readDesktop(entry);
	}
	return result;
}

