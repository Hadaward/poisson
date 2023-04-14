package 
{
	import flash.display.*;
	import flash.events.*;
	import flash.text.*;
	
	public class $Clique extends flash.display.Sprite
	{
		public var Texte:flash.text.TextField;
		public var VignetteTexte:String;
		public var VignetteFixe:int;
		public var VignetteLargeur:int;
		public var VignetteFixeX:int;
		public var VignetteFixeY:int;
		internal var F1:flash.display.MovieClip;
		internal var F2:flash.display.MovieClip;
		internal var Active:Boolean=true;
		internal var Dessus:Boolean=false;
		internal var CouleurPrimaire:uint = 12763866;
		internal var CouleurBase:uint;
		internal var Fonction:Function;
		internal var PosX:int = 10;
		internal var Argument:Boolean=false;
		internal var Arg:*;
		
		public function $Clique(aX:int, aY:int, Texte:String, F:Function, Arg:*=null, Width:int=0) {
			this.CouleurBase = this.CouleurPrimaire;
			super();
			mouseChildren = false;
			this.Fonction = F;
			if (Arg != null) {
				this.Argument = true;
				this.Arg = Arg;
			}
			var Btn:$Btn = new $Btn();
			this.Texte = Btn.T;
			this.Texte.text = Texte;
			this.Texte.autoSize = "left";
			this.F1 = Btn.F1;
			this.F2 = Btn.F2;
			var TexteWidth:int = this.Texte.width;
			if (Width != 0) {
				this.PosX = int((Width + 20 - TexteWidth) / 2);
				TexteWidth = Width;
				this.Texte.x = this.PosX;
			}
			this.F1.M.width = TexteWidth;
			this.F1.D.x = TexteWidth + 10;
			this.F2.M.width = TexteWidth;
			this.F2.D.x = TexteWidth + 10;
			if (aX > 1000) {
				x = int((aX - 1000 - (TexteWidth + 20)) / 2);
			}
			else {
				x = aX;
			}
			y = aY;
			addChild(this.F1);
			addChild(this.Texte);
			addEventListener(flash.events.MouseEvent.MOUSE_OVER, this.Souris_Over);
			addEventListener(flash.events.MouseEvent.MOUSE_OUT, this.Souris_Out);
			addEventListener(flash.events.MouseEvent.MOUSE_DOWN, this.Souris_Clique1);
		}
		
		public function Activation(Active:Boolean):void {
			if (Active && !this.Active || this.Active && !Active) {
				this.Active = Active;
				if (this.Active) {
					mouseEnabled = true;
					if (this.Dessus) {
						this.Texte.textColor = 3178700;
					}
					else {
						this.Texte.textColor = this.CouleurPrimaire;
					}
				}
				else {
					mouseEnabled = false;
					this.Texte.textColor = 6316176;
				}
			}
		}
		
		public function Bloqué(Disabled:Boolean):void {
			if (Disabled) {
				this.CouleurBase = 3178700;
				this.Texte.textColor = 3178700;
			}
			else {
				this.CouleurBase = this.CouleurPrimaire;
				if (this.Active) {
					if (this.Dessus) {
						this.Texte.textColor = 3178700;
					}
					else {
						this.Texte.textColor = this.CouleurPrimaire;
					}
				}
				else {
					this.Texte.textColor = 6316176;
				}
			}
		}
		
		internal function Souris_Clique2(Event:flash.events.Event):void {
			if (this.Active) {
				this.P1();
			}
		}
		
		internal function Souris_Clique1(Event:flash.events.Event):void {
			if (this.Active) {
				this.P2();
			}
		}
		
		public function Couleur_Primaire(Couleur:uint):void {
			this.CouleurPrimaire = Couleur;
			this.CouleurBase = Couleur;
			this.Texte.textColor = Couleur;
		}
		
		internal function P1():void {
			stage.removeEventListener(flash.events.MouseEvent.MOUSE_UP, this.Souris_Clique2);
			this.Texte.x = this.PosX;
			this.Texte.y = 2;
			removeChild(this.F2);
			addChildAt(this.F1, 0);
			if (this.Dessus) {
				if (this.Argument) {
					this.Fonction(this.Arg);
				}
				else {
					this.Fonction();
				}
			}
		}
		
		internal function P2():void {
			this.Texte.x = this.PosX + 1;
			this.Texte.y = 3;
			removeChild(this.F1);
			addChildAt(this.F2, 0);
			stage.addEventListener(flash.events.MouseEvent.MOUSE_UP, this.Souris_Clique2);
		}
		
		internal function Souris_Out(arg1:flash.events.Event):void {
			this.Dessus = false;
			if (this.Active) {
				this.Texte.textColor = this.CouleurBase;
			}
		}
		
		internal function Souris_Over(arg1:flash.events.Event):void {
			this.Dessus = true;
			if (this.Active) {
				this.Texte.textColor = 3178700;
			}
		}
	}
}
