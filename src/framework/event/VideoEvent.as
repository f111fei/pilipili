package framework.event
{
	import flash.events.Event;
	
	public class VideoEvent extends Event
	{
		public static const PLAYHEAD_UPDATE:String = "playheadUpdate"; 
		public static const STATE_CHANGE:String = "stateChange";

		public var state:String;
		public var playheadTime:Number;
		public function VideoEvent(type:String, bubbles:Boolean = false,
								   cancelable:Boolean = false, playheadTime:Number = NaN) 
		{
			super(type, bubbles, cancelable);
			this.playheadTime = playheadTime;
		}
	}
}