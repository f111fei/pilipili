package org.xzper.view
{
	import org.puremvc.as3.interfaces.IMediator;
	import org.puremvc.as3.interfaces.INotification;
	import org.puremvc.as3.patterns.mediator.Mediator;
	
	public class ApplicationMediator extends Mediator implements IMediator
	{
		public static const NAME:String = "ApplicationMediator";
		public function ApplicationMediator(viewComponent:Object)
		{
			super(NAME, viewComponent);
		}
		
		override public function listNotificationInterests():Array
		{
			return new Array;
		}
		
		override public function handleNotification(notification:INotification):void
		{
			switch( notification.getName() )
			{

			}
		}
		
		protected function get main():Main
		{
			return viewComponent as Main;
		}
	}
}