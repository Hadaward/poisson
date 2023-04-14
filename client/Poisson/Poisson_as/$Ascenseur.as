package 
{
	import flash.display.*;
	import flash.events.*;
	import flash.text.*;
	
	public class $Ascenseur extends flash.display.Sprite
	{
		internal var ClipBarre:flash.display.Sprite;
		internal var ClipAscenseur:flash.display.Sprite;
		internal var Texte:flash.text.TextField;
		internal var Largeur:int;
		internal var Hauteur:int;
		internal var PuissanceMolette:int;
		internal var AscenseurCF:uint;
		internal var AscenseurCB:uint;
		internal var DécalageBarreY:int;
		internal var LimiteBarreY:int;
		internal var FinEnCours:Boolean = false;
		
		public function $Ascenseur(Texte:flash.text.TextField, PuissanceMolette:int=1, CF:uint=2236979, CB:uint=40349) {
			super();
			this.Texte = Texte;
			this.Largeur = this.Texte.width;
			this.Hauteur = this.Texte.height - 10;
			this.Texte.mouseWheelEnabled = false;
			this.Texte.mouseEnabled = true;
			mouseChildren = false;
			mouseEnabled = true;
			this.PuissanceMolette = PuissanceMolette;
			this.ClipAscenseur = new flash.display.Sprite();
			this.ClipAscenseur.x = this.Texte.x + this.Largeur + 5;
			this.ClipAscenseur.y = this.Texte.y + 5;
			this.AscenseurCF = CF;
			this.AscenseurCB = CB;
			
			var Shape1:flash.display.Shape = new flash.display.Shape();
			Shape1.graphics.beginFill(0, 0);
			Shape1.graphics.drawRect(-5, 0, 13, this.Hauteur);
			Shape1.graphics.endFill();
			this.ClipAscenseur.addChild(Shape1);
			
			var Shape2:flash.display.Shape = new flash.display.Shape();
			Shape2.graphics.beginFill(this.AscenseurCF);
			Shape2.graphics.drawRect(0, 0, 3, this.Hauteur);
			Shape2.graphics.endFill();
			this.ClipAscenseur.addChild(Shape2);
			this.ClipBarre = new flash.display.Sprite();
			this.ClipAscenseur.addChild(this.ClipBarre);
			addChild(this.ClipAscenseur);
			
			var Shape3:flash.display.Shape = new flash.display.Shape();
			Shape3.graphics.lineStyle(1, 0, 1, true);
			Shape3.graphics.drawRect(0, 0, 3, this.Hauteur);
			Shape3.graphics.endFill();
			this.ClipAscenseur.addChild(Shape3);
			
			addEventListener(flash.events.MouseEvent.MOUSE_WHEEL, this.Utilisation_Molette);
			this.Texte.addEventListener(flash.events.MouseEvent.MOUSE_WHEEL, this.Utilisation_Molette);
			addEventListener(flash.events.MouseEvent.MOUSE_DOWN, this.Clique_Ascenseur);
			this.Texte.parent.addChild(this);
		}
		
		internal function Clique_Ascenseur(Event:flash.events.Event):void {
			this.DécalageBarreY = this.ClipBarre.mouseY;
			stage.addEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Boucle_Ascenseur);
			stage.addEventListener(flash.events.MouseEvent.MOUSE_UP, this.Declique_Ascenseur);
		}
		
		internal function Declique_Ascenseur(Event:flash.events.Event):void {
			stage.removeEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Boucle_Ascenseur);
			stage.removeEventListener(flash.events.MouseEvent.MOUSE_UP, this.Declique_Ascenseur);
		}
		
		internal function Boucle_Ascenseur(Event:flash.events.MouseEvent):void {
			var mY:int = this.ClipAscenseur.mouseY - this.DécalageBarreY;
			if (mY < 0) {
				mY = 0;
			}
			else if (mY > this.LimiteBarreY) {
				mY = this.LimiteBarreY;
			}
			this.ClipBarre.y = mY;
			var sV:Number = Math.ceil(this.Texte.maxScrollV * (this.ClipBarre.y / this.LimiteBarreY));
			if (sV == 0) {
				sV = 1;
			}
			this.Texte.scrollV = sV;
			Event.updateAfterEvent();
		}
		
		internal function Utilisation_Molette(Event:flash.events.MouseEvent):void {
			if (visible) {
				var Scroll:int = 0;
				if (Event.delta < 0) {
					Scroll = this.PuissanceMolette;
				}
				else {
					Scroll = -this.PuissanceMolette;
				}
				this.Texte.scrollV = this.Texte.scrollV + Scroll;
				this.ClipBarre.y = int(this.LimiteBarreY * ((this.Texte.scrollV - 1) / (this.Texte.maxScrollV - 1)));
			}
		}
		
		public function Rendu_Ascenseur(MaxScroll:int):void {
			if (this.Texte.maxScrollV != 1) {
				this.FinEnCours = (this.Texte.scrollV+1) == this.Texte.maxScrollV;
				visible = true;
				var Scroll:int = int(this.Hauteur * ((this.Texte.numLines - this.Texte.maxScrollV) / this.Texte.numLines));
				if (Scroll < 10) {
					Scroll = 10;
				}
				this.ClipBarre.graphics.clear();
				this.ClipBarre.graphics.beginFill(this.AscenseurCB);
				this.ClipBarre.graphics.drawRect(0, 0, 3, Scroll);
				this.ClipBarre.graphics.endFill();
				this.LimiteBarreY = this.Hauteur - Scroll;
				if (MaxScroll == 0) {
					this.Texte.scrollV = 0;
					this.ClipBarre.y = 0;
				}
				else if (MaxScroll == 1) {
					if (this.FinEnCours) {
						this.Texte.scrollV = this.Texte.maxScrollV;
						this.ClipBarre.y = this.LimiteBarreY;
					}
				}
				else if (MaxScroll == 2) {
					this.Texte.scrollV = this.Texte.maxScrollV;
					this.ClipBarre.y = this.LimiteBarreY;
				}
			}
			else {
				this.Texte.scrollV = 1;
				visible = false;
				this.FinEnCours = false;
			}
		}
	}
}
