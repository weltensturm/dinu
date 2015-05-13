module dinu.animation;


import
	std.math,
	std.algorithm,
	std.datetime;


class Animation {
	double start;
	double end;
	double timeStart;
	double duration;
	this(double start, double end, double duration){
		this.start = start;
		this.end = end;
		this.timeStart = Clock.currSystemTick.msecs/1000.0;
		this.duration = duration;
	}
	abstract double func(double completion);
	double calculate(){
		double completion = (timeCurrent - timeStart).min(duration)/duration;
		return start + (end-start)*func(completion);
	}
	bool done(){
		return timeStart+duration < timeCurrent;
	}
	double timeCurrent(){
		return Clock.currSystemTick.msecs/1000.0;
	}
}


class AnimationExpIn: Animation {

	this(double start, double end, double duration){
		super(start, end, duration);
	}

	override double func(double completion){
		return 1-(completion-1).pow(2);
	}

}

class AnimationExpOut: Animation {

	this(double start, double end, double duration){
		super(start, end, duration);
	}

	override double func(double completion){
		return completion.pow(2);
	}

}

