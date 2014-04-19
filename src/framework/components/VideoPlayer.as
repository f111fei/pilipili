package framework.components
{
	import flash.events.Event;
	import flash.events.NetStatusEvent;
	import flash.media.SoundTransform;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	
	import framework.event.VideoEvent;
	import framework.model.VideoInfo;
	
	import mx.core.UIComponent;
	
	/**
	 * 加载完成视频信息
	 */
	[Event(name="metadataReceived", type="flash.events.Event")]
	
	/**
	 * 状态改变
	 */
	[Event(name="stateChange", type="framework.event.VideoEvent")]

	public class VideoPlayer extends UIComponent
	{
		/**
		 * 调用 play() 或 load() 方法后 VideoDisplay.state 属性立即采用的值。
		 */
		public static const BUFFERING:String = "buffering";

		/**
		 * VideoPlayer 控件无法加载视频流时 VideoPlayer.state 属性的值。
		 */
		public static const CONNECTION_ERROR:String = "connectionError";
		
		/**
		 * 视频流超时或空闲时 VideoPlayer.state 属性的值
		 */
		public static const DISCONNECTED:String = "disconnected";
		
		/**
		 * 调用 play() 或 load() 方法后 VideoPlayer.state 属性立即采用的值。
		 */
		public static const LOADING:String = "loading";
		
		/**
		 * FLV 文件已加载但暂停播放时 VideoPlayer.state 属性的值。
		 */
		public static const PAUSED:String = "paused";
		
		/**
		 * FLV 文件已加载并且正在播放时 VideoPlayer.state 属性的值。
		 */
		public static const PLAYING:String = "playing";
		
		/**
		 * 由于设置 VideoPlayer.playHeadTime 属性而进行搜索时 VideoPlayer.state 属性的值。
		 */
		public static const SEEKING:String = "seeking"; 
		
		/**
		 * FLV 文件已加载但播放已停止时 VideoPlayer.state 属性的值。
		 */
		public static const STOPPED:String = "stopped";
		
		private var video:Video = new Video();
		private var netStreams:Array = [];
		private var nc:NetConnection;
		
		/**
		 * 当前的分段
		 */
		private var currentPart:int = 0;
		
		private var videoInfo:VideoInfo;
		
		/**
		 * 已加载元数据的分段数
		 */
		private var loadedPart:int = 0;
		
		public function VideoPlayer()
		{
			videoInfo = new VideoInfo();
		}
		
		override protected function createChildren():void
		{
			super.createChildren();
			video.smoothing = true;
			this.addChild(video);
			autoPlaying();
		}
		
		private var _state:String = DISCONNECTED;
		/**
		 * 控件的当前状态 , 属于VideoPlayer的静态属性
		 */
		public function get state():String 
		{
			return _state;
		}
		
		private var _source:Object;
		private var sourceChange:Boolean = false;

		/**
		 * 视频源  url  或者  VideoInfo  或者  array数组（url的集合）
		 */
		public function get source():Object
		{
			return _source;
		}

		public function set source(value:Object):void
		{
			_source = value;
			videoInfo = parseSource(_source);
			sourceChange = true;
			invalidateProperties();
			autoPlaying();
		}
		
		/**
		 * 视频元数据是否已加载完成
		 */
		public function get isLoadedPart():Boolean
		{
			if(loadedPart == 0 && partNum == 0){
				return false;
			}
			return loadedPart == partNum;
		}
		
		/**
		 * 获取视频的分段数
		 */
		public function get partNum():int
		{
			return videoInfo?videoInfo.parts.length:0;
		}
		
		private function getNetStream(index:int):NetStream
		{
			if(netStreams.length>index && netStreams[index]){
				return netStreams[index] as NetStream;
			}
			return null;
		}
		
		/**
		 * 视频开始播放后，playhead 的当前时间（以秒为单位）。
		 */
		public function get currentTime():Number
		{
			var totalTime:Number = 0;
			for (var i:int = 0; i < currentPart; i++) 
			{
				totalTime += videoInfo.parts[i].length;
			}
			var currentNetStream:NetStream = getNetStream(currentPart);
			if(currentNetStream){
				totalTime += currentNetStream.time * 1000;
			}
			return totalTime/1000;
		}
		
		private function autoPlaying():void
		{
			if (_source)
			{
				if (_autoPlay)
					play();
				else
					load();
			}
		}
		
		public function load():void
		{
			
		}
		
		/**
		 * 播放视频
		 */
		public function play():void
		{
			if(!isXnOK())
			{
				if (_state != CONNECTION_ERROR)
				{
					setupSource();
				}
				return;
			}
			var currentNS:NetStream = getNetStream(currentPart);
			if(!currentNS){
				return;
			}
			switch (_state) 
			{
				case BUFFERING:
				case PLAYING:
					return;
				case STOPPED:
				case PAUSED:
					currentNS.resume();
					setState(PLAYING);
			};
		}
		
		/**
		 * 暂停
		 */
		public function pause():void {
			if(!isXnOK()){
				return;
			}
			var currentNS:NetStream = getNetStream(currentPart);
			if(_state == PAUSED || _state == STOPPED || currentNS == null){
				return;
			}
			currentNS.pause();
			setState(PAUSED);
		}
		
		/**
		 * 获取是否连接完毕
		 */
		private function isXnOK():Boolean 
		{
			if(_state == LOADING) return true;
			if(_state == CONNECTION_ERROR) return false;
			if(_state != DISCONNECTED) 
			{
				if (!nc || !nc.connected)
				{
					setState(DISCONNECTED);
					return false;
				}
				return true;
			}
			return false;
		}
		
		/**
		 * 跳转  time以秒为单位
		 */
		public function seek(time:Number):void{
			var obj:Object = getPartByTime(time*1000);
			var partIndex:int = obj["index"];
			var partOffset:int = obj["offset"];

			seekInPart(partIndex, partOffset/1000);
		}
		
		private function seekInPart(index:int , time:Number):void
		{
			if(!isXnOK()) 
			{
				if(_state != CONNECTION_ERROR)
				{
					setState(LOADING);
					setupSource();
					return;
				}
			}
			if (index >= partNum){
				return;
			}
			
			var flag:Boolean = false;
			switch (_state) 
			{
				case BUFFERING:
					flag = true;
					return;
				case PLAYING:
				case PAUSED:
					flag = true;
					setState(SEEKING);
					break;
				case STOPPED:
					flag = true;
					_state = PAUSED;
					setState(SEEKING);
					break;
				case SEEKING:
					flag = true;
					break;
			};
			if(flag){
				if(index == currentPart){
					getNetStream(index).seek(time);
				}else{
					getNetStream(currentPart).pause();
					getNetStream(index).seek(time);
					video.clear();
					video.attachNetStream(getNetStream(index));
					currentPart = index;
				}
				getNetStream(index).resume();
			}
		}
		
		private function changePart(partIndex:int):void
		{
			if(partIndex>=partNum){
				seekInPart(0 , 0);
				pause();
			}else{
				seekInPart(partIndex , 0);
			}
		}
		
		/**
		 * 获取指定时间的分段和偏移    以毫秒为单位    {"index"   ,   "offset"}
		 */
		private function getPartByTime(time:Number):Object
		{
			var totalTime:Number = 0;
			var offset:Number = time;
			var i:int = 0;
			while(i<partNum){
				totalTime += videoInfo.parts[i]["length"];
				if(totalTime >= time){
					break;
				}else{
					offset -= videoInfo.parts[i]["length"];
					i++;
				}
			}
			return {"index":i , "offset":offset};
		}
		
		
		/**
		 * 解析source参数
		 */
		private function parseSource(obj:Object):VideoInfo
		{
			var vi:VideoInfo = new VideoInfo();
			if(obj is String){
				vi.timelength = 0;
				vi.parts = [{"length":0,"url":obj}]
			}else if(obj is VideoInfo){
				vi = obj as VideoInfo;
			}else if(obj is Array){
				//TODO
			}
			return vi;
		}
		
		private var _bufferTime:Number = 4000;
		/**
		 * 开始播放视频文件前在内存中缓冲视频的毫秒数。
		 */
		public function get bufferTime():Number
		{
			return _bufferTime;
		}

		public function set bufferTime(value:Number):void
		{
			_bufferTime = value;
		}
		
		private var _autoPlay:Boolean = true;
		/**
		 * 指定设置 source 属性后视频是否应立即开始播放。
		 */
		public function get autoPlay():Boolean
		{
			return _autoPlay;
		}

		public function set autoPlay(value:Boolean):void
		{
			_autoPlay = value;
		}

		
		private var _soundTransform:SoundTransform;
		
		/**
		 * 加载视频源信息
		 */
		private function setupSource():void
		{
			if(_source){
				sourceChange = false;
				setState(LOADING);
				currentPart = 0;
				loadedPart = 0;
				createStreams();
				video.clear();
				if(partNum!=0){
					video.attachNetStream(netStreams[0]);
				}
			}
		}
		
		private function createStreams():void
		{
			destroyStreams();
			nc = new NetConnection();
			nc.addEventListener(NetStatusEvent.NET_STATUS , httpOnStatus);
			nc.connect(null);
			for (var i:int = 0; i < partNum; i++) 
			{
				var ns:NetStream = createOneStream();
				try
				{
					ns.play(videoInfo.parts[i]["url"]);
				}
				catch (e:Error)
				{
					trace(e);
				}
				ns.pause();
				netStreams.push(ns);
			}
		}
		
		private function destroyStreams():void
		{
			for (var i:int = 0; i < netStreams.length; i++) 
			{
				var ns:NetStream = netStreams[i] as NetStream;
				ns.pause();
				ns.close();
			}
			if(nc){
				nc.close();
			}
			netStreams.length = 0;
		}
		
		private function createOneStream():NetStream 
		{
			var nsClient:Object=new Object();
			nsClient.onMetaData=function onMetaData(o:Object):void
			{
				loadedMetaData(o , ns);
			}
			var ns:NetStream = new NetStream(nc);
			ns.client = nsClient;
			ns.bufferTime = _bufferTime/1000;
			ns.soundTransform = _soundTransform;
			ns.addEventListener(NetStatusEvent.NET_STATUS,  httpOnStatus);
			return ns;
		}
		
		private function httpOnStatus(event:NetStatusEvent):void
		{
//			trace(netStreams.indexOf(event.currentTarget) , event.info.code);
			switch (event.info.code)
			{
				case "NetStream.Play.Stop":
					partPlayEnd(event.currentTarget as NetStream);
					break;
				case "NetStream.Seek.InvalidTime":     //搜寻到还未加载的位置
					_state = SEEKING;
					seekInPart(currentPart , event.info.details);
					break;
				case "NetStream.Seek.Complete":		//搜寻操作完成，进入缓冲
					_state = cacheState;
					setState(BUFFERING);
					break;
				case "NetStream.Buffer.Empty":
					break;
				case "NetStream.Buffer.Full":				//缓冲完毕
				case "NetStream.Buffer.Flush":
					if(_state == SEEKING || _state == BUFFERING){
						setState(cacheState);
					}else if(_state == LOADING)
					{
						setState(PLAYING);
					}
					break;
				case "NetStream.Seek.Notify":
					break;    
				case "NetStream.Play.StreamNotFound":
					setState(CONNECTION_ERROR);
					break;
			}
		}
		
		private function partPlayEnd(ns:NetStream):void
		{
			var offset:Number = Math.abs(ns.time-ns.info.metaData.duration);
			if(netStreams.indexOf(ns) == currentPart && offset<5){  //播放结束
				if(offset<1){
					if(currentPart == partNum-1){
						setState(STOPPED);
					}
					changePart(currentPart+1);
				}else{
					ns.seek(ns.time);
				}
			}
		}
		
		/**
		 * 获取到视频信息
		 */
		private function loadedMetaData(info:Object , ns:NetStream):void
		{
			var index:int = netStreams.indexOf(ns);
			if(index<0){   //防止多次设置的ns不存在在当前列表的错误
				return;
			}
			if(index==0){
				video.width = info["width"];
				video.height = info["height"];
				invalidateSize();
				invalidateDisplayList();
			}
			if(partNum==1 && videoInfo.timelength == 0){
				videoInfo.timelength = info["duration"]*1000;
				videoInfo.parts[index]["length"] = videoInfo.timelength;
			}
			loadedPart++;
			if(partNum == loadedPart){
				setState(PAUSED);
				autoPlaying();
				dispatchEvent(new Event("metadataReceived"));
			}
		}
		
		private var cacheState:String  = state;
		private function setState(s:String):void 
		{
			if (s == _state) 
				return;
			cacheState = _state;
			_state = s;
			var videoEvent:VideoEvent = new VideoEvent(VideoEvent.STATE_CHANGE);
			var ns:NetStream = getNetStream(currentPart);
			var playheadTime:Number = 0;
			if(ns){
				playheadTime = ns.time;
			}
			videoEvent.playheadTime = playheadTime;
			videoEvent.state = s;
			dispatchEvent(videoEvent);
		}
		
		override protected function commitProperties():void
		{
			super.commitProperties();
			if(sourceChange){
				setupSource();
			}
		}
		
		override protected function measure():void
		{
			super.measure();
			this.measuredWidth = video.width;
			this.measuredHeight = video.height;
		}
		
		override protected function updateDisplayList(unscaledWidth:Number, unscaledHeight:Number):void
		{
			super.updateDisplayList(unscaledWidth,unscaledHeight);
			video.width = unscaledWidth;
			video.height = unscaledHeight;
		}
	}
}