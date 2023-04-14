package 
{
	import flash.display.*;
	import flash.events.*;
	
	public class $Liste extends flash.display.Sprite
	{
		public var VignetteTexte:String;
		public var VignetteLargeur:int;
		public var VignetteFixe:int;
		public var VignetteFixeY:int;
		public var VignetteFixeX:int;
		public var HauteurClip:int;
		internal var HauteurAscenseur:int;
		internal var Hauteur:int;
		internal var HauteurFixe:Boolean;
		internal var ClipAscenseur:flash.display.Sprite;
		internal var AscenseurCB:uint;
		internal var AscenseurCF:uint;
		internal var AscenseurActif:Boolean=false;
		internal var RenduRestant:int;
		internal var BaseY:int;
		internal var LimiteY:int;
		internal var DécalageBarreY:int;
		internal var LimiteBarreY:int;
		internal var ClipBarre:flash.display.Sprite;
		internal var Boite:flash.display.Sprite;
		internal var PuissanceMolette:int;
		internal var Fond:flash.display.Shape;
		internal var Interval:int;
		internal var Liste:Array;
		internal var FinEnCours:Boolean=false;
		internal var Largeur:int;
		internal var RenduEnCours:int;
		internal var FonctionRendu:Function;
		internal var Masque:flash.display.Shape;
		
		public function $Liste(Largeur:int, Hauteur:int, Fixe:int=0, Bg:Boolean=true, Interval:int=0) {
			this.Liste = new Array();
			this.Boite = new flash.display.Sprite();
			super();
			mouseEnabled = false;
			this.Boite.mouseEnabled = false;
			this.Interval = Interval;
			this.Largeur = Largeur;
			this.Hauteur = Hauteur;
			this.HauteurAscenseur = this.Hauteur - 20;
			if (Fixe != 0) {
				this.HauteurFixe = true;
				this.HauteurClip = Fixe + this.Interval;
			}
			else {
				this.HauteurFixe = false;
			}
			this.Fond = new flash.display.Shape();
			this.Masque = new flash.display.Shape();
			if (Bg) {
				this.Fond.graphics.lineStyle(2, 0, 1, true);
				this.Fond.graphics.beginFill(3947605);
				this.Fond.graphics.drawRoundRect(0, 0, this.Largeur, this.Hauteur, 20);
				this.Fond.graphics.endFill();
				this.Masque.graphics.beginFill(0);
				this.Masque.graphics.drawRoundRect(1, 1, this.Largeur - 2, this.Hauteur - 2, 20);
				this.Masque.graphics.endFill();
			}
			else {
				this.Fond.graphics.beginFill(0, 0);
				this.Fond.graphics.drawRect(0, 0, this.Largeur, this.Hauteur);
				this.Fond.graphics.endFill();
				this.Masque.graphics.beginFill(0);
				this.Masque.graphics.drawRect(1, 1, this.Largeur, this.Hauteur);
				this.Masque.graphics.endFill();
			}
			this.Boite.mask = this.Masque;
			if (this.Fond) {
				addChild(this.Fond);
			}
			addChild(this.Boite);
			addChild(this.Masque);
		}
		
		internal function Boucle_Ascenseur(Event:flash.events.MouseEvent):void {
			var cby:int = this.ClipAscenseur.mouseY - this.DécalageBarreY;
			if (cby < 0) {
				cby = 0;
			}
			else if (cby > this.LimiteBarreY) {
				cby = this.LimiteBarreY;
			}
			this.ClipBarre.y = cby;
			this.Boite.y = int(this.LimiteY * (this.ClipBarre.y / this.LimiteBarreY));
			Event.updateAfterEvent();
		}
		
		public function Rendu_Ascenseur():void {
			if ((this.Hauteur / this.BaseY) >= 1) {
				this.Boite.y = 0;
				this.ClipAscenseur.visible = false;
				this.FinEnCours = false;
			}
			else {
				this.FinEnCours = this.Boite.y == this.LimiteY;
				this.ClipAscenseur.visible = true;
				var aY:int = int(this.HauteurAscenseur * (this.Hauteur / this.BaseY));
				if (aY < 10) {
					aY = 10;
				}
				this.ClipBarre.graphics.clear();
				this.ClipBarre.graphics.beginFill(this.AscenseurCB);
				this.ClipBarre.graphics.drawRect(0, 0, 3, aY);
				this.ClipBarre.graphics.endFill();
				this.LimiteY = this.Hauteur - this.BaseY;
				this.LimiteBarreY = this.HauteurAscenseur - aY;
			}
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
		
		public function Ajout_Element(Element:flash.display.MovieClip, Démarrer:Boolean=false):void {
			Element.visible = false;
			if (Démarrer) {
				this.Liste.unshift(Element);
				this.Boite.addChildAt(Element, 0);
			}
			else {
				this.Liste.push(Element);
				this.Boite.addChild(Element);
			}
		}
		
		public function Suppr_Element(arg1:flash.display.MovieClip):void {
			var Pos:*=0;
			while (Pos < this.Liste.length) {
				if (this.Liste[Pos] == arg1) {
					this.Liste.splice(Pos, 1);
					this.Boite.removeChild(arg1);
					return;
				}
				++Pos;
			}
		}
		
		public function Ascenseur(PM:int=80, CF:uint=2236979, CB:uint=40349):void {
			if (!this.AscenseurActif) {
				mouseEnabled = true;
				this.AscenseurActif = true;
				this.PuissanceMolette = PM;
				this.ClipAscenseur = new flash.display.Sprite();
				this.ClipAscenseur.x = this.Largeur - 3;
				this.ClipAscenseur.y = 10;
				this.AscenseurCF = CF;
				this.AscenseurCB = CB;
				
				var S1:flash.display.Shape = new flash.display.Shape();
				S1.graphics.beginFill(0, 0);
				S1.graphics.drawRect(-5, 0, 13, this.HauteurAscenseur);
				S1.graphics.endFill();
				this.ClipAscenseur.addChild(S1);
				
				var S2:flash.display.Shape = new flash.display.Shape();
				S2.graphics.beginFill(this.AscenseurCF);
				S2.graphics.drawRect(0, 0, 3, this.HauteurAscenseur);
				S2.graphics.endFill();
				this.ClipAscenseur.addChild(S2);
				this.ClipBarre = new flash.display.Sprite();
				this.ClipAscenseur.addChild(this.ClipBarre);
				addChild(this.ClipAscenseur);
				
				var S3:flash.display.Shape = new flash.display.Shape();
				S3.graphics.lineStyle(1, 0, 1, true);
				S3.graphics.drawRect(0, 0, 3, this.HauteurAscenseur);
				S3.graphics.endFill();
				this.ClipAscenseur.addChild(S3);
				
				this.ClipAscenseur.mouseChildren = false;
				addEventListener(flash.events.MouseEvent.MOUSE_WHEEL, this.Utilisation_Molette);
				this.ClipAscenseur.addEventListener(flash.events.MouseEvent.MOUSE_DOWN, this.Clique_Ascenseur);
			}
		}
		
		public function Vider():void {
			if (this.RenduRestant != 0) {
				this.RenduRestant = 0;
				removeEventListener(flash.events.Event.ENTER_FRAME, this.Boucle);
			}
			while (this.Boite.numChildren != 0) {
				this.Boite.removeChildAt(0);
			}
			this.Liste = new Array();
		}
		
		public function Position(Pos:int = 0):void {
			if (Pos == 0) {
				this.Boite.y = 0;
				this.ClipBarre.y = 0;
			}
			else if (Pos == 1) {
				if (this.FinEnCours) {
					this.Boite.y = this.LimiteY;
					this.ClipBarre.y = this.LimiteBarreY;
				}
			}
			else if (Pos == 2) {
				this.Boite.y = this.LimiteY;
				this.ClipBarre.y = this.LimiteBarreY;
			}
		}
		
		public function MAJ_Hauteur(Pos:int):void {
			this.BaseY = this.Boite.height + this.Interval * 2;
			if (this.AscenseurActif) {
				this.Rendu_Ascenseur();
				this.Position(Pos);
			}
		}
		
		public function Rendu(fieldName:String=null, options:int=0, Fonction:Function=null):void {
			if (fieldName) {
				this.Liste.sortOn(fieldName, options);
			}
			this.BaseY = this.Interval;
			if (Fonction == null)  {
				var Pos:int = 0;
				while (Pos < this.Liste.length)  {
					var Element:* = this.Liste[Pos];
					Element.y = this.BaseY;
					if (this.HauteurFixe) {
						this.BaseY = this.BaseY + this.HauteurClip;
					}
					else {
						this.BaseY = this.BaseY + int(Element.height) + this.Interval;
					}
					Element.visible = true;
					++Pos;
				}
				if (this.AscenseurActif) {
					this.Rendu_Ascenseur();
				}
			}
			else {
				this.RenduRestant = this.Liste.length;
				this.RenduEnCours = 0;
				this.FonctionRendu = Fonction;
				addEventListener(flash.events.Event.ENTER_FRAME, this.Boucle);
			}
		}
		
		internal function Utilisation_Molette(Souris:flash.events.MouseEvent):void {
			if (this.AscenseurActif && this.ClipAscenseur.visible) {
				var Dir:int = 0;
				if (Souris.delta < 0) {
					Dir = -this.PuissanceMolette;
				}
				else {
					Dir = this.PuissanceMolette;
				}
				this.Boite.y = this.Boite.y + Dir;
				if (this.Boite.y > 0) {
					this.Boite.y = 0;
				}
				else if (this.Boite.y < this.LimiteY) {
					this.Boite.y = this.LimiteY;
				}
				this.ClipBarre.y = int(this.LimiteBarreY * (this.Boite.y / this.LimiteY));
			}
		}
		
		internal function Boucle(Event:flash.events.Event):void {
			if (this.RenduRestant != 0) {
				var Element:* = this.Liste[this.RenduEnCours];
				Element = this.FonctionRendu(Element);
				Element.y = this.BaseY;
				if (this.HauteurFixe) {
					this.BaseY = this.BaseY + this.HauteurClip;
				}
				else {
					this.BaseY = this.BaseY + int(Element.height) + this.Interval;
				}
				Element.visible = true;
				this.RenduEnCours = this.RenduEnCours + 1;
				this.RenduRestant = this.RenduRestant - 1;
			}
			else {
				removeEventListener(flash.events.Event.ENTER_FRAME, this.Boucle);
				if (this.AscenseurActif) {
					this.Rendu_Ascenseur();
				}
			}
		}
	}
}
