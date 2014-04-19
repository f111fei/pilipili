package framework.model
{
	public class VideoInfo
	{
		/**
		 * 视频的长度 毫秒
		 */
		public var timelength:uint = 0;
		
		/**
		 * 每一项有属性  length 毫秒 url
		 */
		public var parts:Array = [];
		
		public function VideoInfo()
		{
		}
	}
}