package Poisson_fla 
{
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
	
	public dynamic class _Serveur_1 extends flash.display.MovieClip
	{
		public var _root:flash.display.MovieClip;
		public var _I:flash.display.MovieClip;
		public var _Salon:flash.text.TextField;
		public var Texte:flash.text.TextField;
		public var Image:flash.display.MovieClip;
		public var Connexion:$Clique;
		public var Exe:flash.text.TextField;
		public var EffacePseudoId:Boolean;
		
		public function _Serveur_1() {
			super();
			addFrameScript(0, this.frame1);
		}
		
		function frame1():void {
			this._root = parent as flash.display.MovieClip;
			this.EffacePseudoId = true;
			mouseEnabled = true;
			this._I.visible = false;
			this._I._Texte.restrict = "A-Za-z";
			if (this._root.SalonCible != "1") {
				this._Salon.text = this._root.SalonCible;
			}
			try {
				this.Image = new (this.loaderInfo.applicationDomain.getDefinition("$ImageConnexion") as Class)();
				addChild(this.Image);
				this.Image.x = 70;
				this.Image.y = 147;
			}
			catch (E:Error) { };
			this.Connexion = new $Clique(0, 25, "Valider", this.Validation, null, 90);
			this.Connexion.Activation(false);
			this._I.addChild(this.Connexion);
			this.Exe.styleSheet = this._root.StyleTexte;
			this.Exe.mouseEnabled = true;
			this._I._Texte.addEventListener(flash.events.FocusEvent.FOCUS_IN, this.E_PseudoId);
			this._I._Texte.addEventListener(flash.events.KeyboardEvent.KEY_DOWN, this.Clavier);
		}

		public function E_PseudoId(Event:flash.events.Event):void {
			if (this.EffacePseudoId) {
				this._I._Texte.removeEventListener(flash.events.FocusEvent.FOCUS_IN, this.E_PseudoId);
				this.Connexion.Activation(true);
				this.EffacePseudoId = false;
				this._I._Texte.text = "";
			}
		}

		public function Clavier(Event:flash.events.KeyboardEvent):void {
			if (Event.keyCode == 13 && this._I._Texte.text) {
				this._I._Texte.removeEventListener(flash.events.KeyboardEvent.KEY_DOWN, this.Clavier);
				this.Validation();
			}
		}
		
		public function Validation():void {
			this._root.Envoie_Serveur(this._root.$26 + this._root.$4 + this._root.$1 + this._I._Texte.text + this._root.$1 + this._root.SalonCible);
		}
	}
}
