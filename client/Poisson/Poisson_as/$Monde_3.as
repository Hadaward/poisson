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
	
	public dynamic class $Monde_3 extends flash.display.MovieClip
	{
		public var _root:flash.display.MovieClip;
		public var PosX:int;
		public var PosY:int;
		public var m_physScale:Number;
		public var M:flash.display.MovieClip;
		public var ObjetInterdit:Array;
		
		public function $Monde_3() {
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
			this.ObjetInterdit = new Array(7, 17);
			this.PosX = 1;
			this.PosY = 10;
		}
		
		public function Initialisation_Forme(mc:flash.display.MovieClip):void {
			var Pos:int = 1;
			while (Pos < 10) {
				var BodyDef:b2BodyDef = new Box2D.Dynamics.b2BodyDef();
				BodyDef.position.x = Pos / 10 * 15 + 5;
				BodyDef.position.y = 8;
				var hx:Number = 1 - Pos / 10 + 0.5;
				var hy:Number = 1 - Pos / 10 + 0.5;
				if (Pos % 2 == 0) {
					BodyDef.position.x = 3;
					BodyDef.position.y = 8 - Pos;
					var PolygonDef:b2PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
					PolygonDef.filter.categoryBits = 4;
					PolygonDef.SetAsBox(hx, hy);
					PolygonDef.density = 10;
					PolygonDef.friction = 0.5;
					PolygonDef.restitution = 0.2;
					BodyDef.userData = new PhysBox();
					BodyDef.userData.width = hx * 2 * 30;
					BodyDef.userData.height = hy * 2 * 30;
					var Mobile:b2Body = this._root.MondePhysique.CreateBody(BodyDef);
					Mobile.CreateShape(PolygonDef);
					Mobile.SetMassFromShapes();
					mc.addChild(BodyDef.userData);
					this._root.ListeMobile.push(Mobile);
				}
				++Pos;
			}
		}
		
		public function Initialisation_Sol(ListeMobile:flash.display.MovieClip):void {
			var BodyDef:b2BodyDef = new Box2D.Dynamics.b2BodyDef();
			var UserData:MovieClip = new flash.display.MovieClip();
			BodyDef.position.Set(0, 0);
			BodyDef.userData = UserData;
			ListeMobile.addChild(BodyDef.userData);
			this._root.MondePhysique.CreateBody(BodyDef).CreateShape(this._root.Mobile_Statique(UserData, new Array(300, 100, 320, 325, 340, 100)));
		}
		
		public function Initialisation_Pont(mc:flash.display.MovieClip):void {
			var Vec2:Box2D.Common.Math.b2Vec2 = new Box2D.Common.Math.b2Vec2();
			var PolygonDef:Box2D.Collision.Shapes.b2PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
			PolygonDef.SetAsBox(24 / this.m_physScale, 5 / this.m_physScale);
			PolygonDef.density = 20;
			PolygonDef.friction = 0.2;
			PolygonDef.filter.categoryBits = 4;
			var JointDef:Box2D.Dynamics.Joints.b2RevoluteJointDef = new Box2D.Dynamics.Joints.b2RevoluteJointDef();
			var MobileCount:int =  15;
			JointDef.lowerAngle = -15 / (180 / Math.PI);
			JointDef.upperAngle = 15 / (180 / Math.PI);
			JointDef.enableLimit = true;
			var gba:b2Body = this._root.MondePhysique.GetGroundBody();
			var gbb:b2Body = gba;
			var Pos:int = 0;
			while (Pos < MobileCount) {
				var BodyDef:Box2D.Dynamics.b2BodyDef = new Box2D.Dynamics.b2BodyDef();
				BodyDef.userData = new Planche();
				mc.addChild(BodyDef.userData);
				BodyDef.position.Set((200 + 22 + 44 * Pos) / this.m_physScale, 3);
				var gbc:b2Body = this._root.MondePhysique.CreateBody(BodyDef);
				this._root.ListeMobile.push(gbc);
				gbc.CreateShape(PolygonDef);
				gbc.SetMassFromShapes();
				Vec2.Set((200 + 44 * Pos) / this.m_physScale, 3);
				JointDef.Initialize(gbb, gbc, Vec2);
				this._root.MondePhysique.CreateJoint(JointDef);
				gbb = gbc;
				++Pos;
			}
			Vec2.Set((100 + 44 * MobileCount) / this.m_physScale, 250 / this.m_physScale);
			JointDef.Initialize(gbb, gba, Vec2);
			this._root.MondePhysique.CreateJoint(JointDef);
		}
	}
}
