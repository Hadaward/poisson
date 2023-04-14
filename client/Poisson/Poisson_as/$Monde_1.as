package 
{
	import Box2D.Collision.*;
	import Box2D.Collision.Shapes.*;
	import Box2D.Common.Math.*;
	import Box2D.Dynamics.*;
	import Box2D.Dynamics.Joints.*;
	import adobe.utils.*;
	import flash.accessibility.*;
	import flash.desktop.*;
	import flash.display.*;
	import flash.errors.*;
	import flash.events.*;
	import flash.external.*;
	import flash.filters.*;
	import flash.geom.*;
	import flash.media.*;
	import flash.net.*;
	import flash.printing.*;
	import flash.profiler.*;
	import flash.sampler.*;
	import flash.system.*;
	import flash.text.*;
	import flash.text.engine.*;
	import flash.ui.*;
	import flash.utils.*;
	import flash.xml.*;
	
	public dynamic class $Monde_1 extends flash.display.MovieClip
	{
		public var _root:flash.display.MovieClip;
		public var PosX:int;
		public var PosY:int;
		public var m_physScale:Number;
		public var M:flash.display.MovieClip;
		
		public function $Monde_1() {
			super();
			addFrameScript(0, this.frame1);
		}
		
		internal function frame1():void {
			return;
		}
		
		public function Initialisation(root:flash.display.MovieClip, ListeMobile:flash.display.MovieClip):void {
			this.m_physScale = 30;
			this._root = root;
			this._root.Initialisation_Base(this);
			this.Initialisation_Sol(ListeMobile);
			this.PosX = 1;
			this.PosY = 1;
		}
		
		public function Initialisation_Sol(ListeMobile:flash.display.MovieClip):void {
			var BodyDef:b2BodyDef = new Box2D.Dynamics.b2BodyDef();
			var UserData:MovieClip = new flash.display.MovieClip();
			BodyDef.position.Set(0, 0);
			BodyDef.userData = UserData;
			ListeMobile.addChild(BodyDef.userData);
			this._root.MondePhysique.CreateBody(BodyDef).CreateShape(this._root.Mobile_Statique(UserData, new Array(0, 400, 0, 50, 50, 50, 600, 400)));
		}
	}
}
