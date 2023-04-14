package Poisson_fla 
{
	import flash.display.JointStyle;
	import flash.display.MovieClip;
	import flash.events.DataEvent;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.KeyboardEvent;
	import flash.events.MouseEvent;
	import flash.events.SecurityErrorEvent;
	import flash.events.TimerEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Point;
	import flash.net.XMLSocket;
	import flash.system.ApplicationDomain;
	import flash.system.Security;
	import flash.text.StyleSheet;
	import flash.text.TextField;
	import flash.text.TextFieldType;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	import flash.utils.getTimer;
	import Box2D.Collision.b2AABB;
	import Box2D.Collision.Shapes.b2CircleDef;
	import Box2D.Collision.Shapes.b2MassData;
	import Box2D.Collision.Shapes.b2PolygonDef;
	import Box2D.Common.Math.b2Vec2;
	import Box2D.Dynamics.b2Body;
	import Box2D.Dynamics.b2BodyDef;
	import Box2D.Dynamics.b2World;
	import Box2D.Dynamics.Joints.b2RevoluteJointDef;
	import __AS3__.vec.Vector;
	import fl.transitions.Tween;
	import fl.transitions.TweenEvent;
	
	public dynamic class MainTimeline extends flash.display.MovieClip
	{
		public const DEBUG:Boolean = false;
		public var Version:String;
		public var MauvaiseVersion:Boolean;
		public var Serveur:flash.net.XMLSocket;
		public var Adresse:String;
		public var Domaine:String;
		public var SalonCible:String;
		public var InfoSalon:Array;
		
		public var CodeJoueur:int;
		public var NomJoueur:String;
		public var NomGuide:String;
		public var Admin:Boolean;
		public var Modo:Boolean;
		public var Guide:Boolean;
		public var DernierMessage:String;
		public var DernièreAction:int;
		public var Synchroniseur:Boolean;
		
		public var MoteurActif:Boolean;
		public var worldAABB:Box2D.Collision.b2AABB;
		public var MondePhysique:Box2D.Dynamics.b2World;
		public var PhysiqueSol:Box2D.Dynamics.b2Body;
		public var NombreObjet:int;
		public var m_timeStep:Number;
		public var m_iterations:int;
		public var ImagesCalculées:int;
		public var TADT:int;
		public var TempsZéro:int;
		public var TexteArrêtDuTemps:flash.text.TextField;
		public var ArrêtDuTempsZéro:int;
		public var ArrêtDuTempsEnCours:Boolean;
		public var TempsPartieZéro:int;
		public var TempsEnCours:int;
		public var TempsZeroBR:int;
		
		public var $1:String;
		public var $2:String;
		public var $3:String;
		public var $4:String;
		public var $5:String;
		public var $6:String;
		public var $7:String;
		public var $8:String;
		public var $11:String;
		public var $12:String;
		public var $14:String;
		public var $15:String;
		public var $16:String;
		public var $18:String;
		public var $20:String;
		public var $21:String;
		public var $22:String;
		public var $24:String;
		public var $25:String;
		public var $26:String;
		public var $27:String;
		
		public var _Serveur:flash.display.MovieClip;
		public var _Vignette:flash.display.MovieClip;
		public var _I:flash.display.MovieClip;
		public var _M:flash.display.MovieClip;
		public var TexteServeur:flash.text.TextField;
		public var TexteChat:flash.text.TextField;
		public var CE:flash.text.TextField;
		public var Monde:flash.display.MovieClip;
		public var ObjetEnCours:flash.display.MovieClip;
		public var ClipListeJoueur:flash.display.MovieClip;
		public var ClipMonde:flash.display.MovieClip;
		public var ClipServeur:flash.display.MovieClip;
		public var ClipListeMobile:flash.display.MovieClip;
		public var ClipJoueur:flash.display.MovieClip;
		public var ClipInterface:flash.display.MovieClip;
		public var ClipIdentification:flash.display.MovieClip;
		public var ClipVignette:$ClipVignette;
		public var ClipJoueurProp:Box2D.Collision.Shapes.b2CircleDef;
		public var VignetteEnCours:Object;
		public var AnimVignette:fl.transitions.Tween;
		
		public var InterfaceListeObjet:$Liste;
		public var ListeObjetDispo:Array;
		public var ListeMessage:__AS3__.vec.Vector.<String>;
		public var ListeMobile:Array;
		public var ListeJoueur:flash.utils.Dictionary;
		public var InterfaceListeJoueur:$Liste;
		
		public var NomObjet:Array;
		public var AutoClou:Boolean;
		public var AutoClouCode:int;
		public var AutoClouDécalage:int;
		public var AscenseurChat:$Ascenseur;
		public var LimiteChat:int;
		public var DernierSaut:int;
		public var SautDisponible:Boolean;
		public var LimiteX:int;
		public var LimiteY:int;
		public var Restriction:String;
		public var StyleTexte:flash.text.StyleSheet;
		public var VraiLargeur:int;
		public var BoucleReveille:flash.utils.Timer;
		public var TimerPosition:flash.utils.Timer;

		public function MainTimeline() {
			super();
			addFrameScript(0, this.frame1);
		}

		function frame1():void {
			this.ClipMonde = this._M;
			this.ClipListeJoueur = this.ClipMonde._ListeJoueur;
			this.ClipListeMobile = this.ClipMonde._ListeMobile;
			this.ClipServeur = this._Serveur;
			this.ClipIdentification = this._Serveur._I;
			this.ClipInterface = this._I;
			this.ClipInterface.mouseEnabled = false;
			this.TexteServeur = this._Serveur.Texte;
			this.NomObjet = new Array();
			this.MoteurActif = false;
			this.ListeObjetDispo = new Array(0, 1, 2, 3, 4, 6, 7, 8, 10, 22, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20);
			this.NomObjet[0] = "Flèche indicative";
			this.NomObjet[1] = "Petite caisse";
			this.NomObjet[2] = "Grosse caisse";
			this.NomObjet[3] = "Petite planche";
			this.NomObjet[4] = "Grande planche";
			this.NomObjet[5] = "Balle lourde";
			this.NomObjet[6] = "Balle";
			this.NomObjet[7] = "Trampoline ";
			this.NomObjet[8] = "Petite planche rugueuse";
			this.NomObjet[9] = "Grande planche rugueuse";
			this.NomObjet[10] = "Boite lourde";
			this.NomObjet[11] = "Clou fixe";
			this.NomObjet[12] = "Moteur fixe droite";
			this.NomObjet[13] = "Moteur fixe gauche";
			this.NomObjet[14] = "Clou (Touche V pour associer avec un autre objet)";
			this.NomObjet[15] = "Moteur droite";
			this.NomObjet[16] = "Moteur gauche";
			this.NomObjet[17] = "Boulet";
			this.NomObjet[18] = "Boulet";
			this.NomObjet[19] = "Boulet";
			this.NomObjet[20] = "Boulet";
			this.NomObjet[21] = "Balle collante";
			this.NomObjet[22] = "Clou semi fixe (Touche C pour associer avec un autre objet)";
			this.ListeJoueur = new flash.utils.Dictionary();
			this.Synchroniseur = false;
			this.Guide = false;
			this.ArrêtDuTempsEnCours = false;
			this.TexteArrêtDuTemps = this.ClipInterface._AT;
			this.TexteArrêtDuTemps.mouseEnabled = false;
			this.SautDisponible = false;
			this.AutoClou = false;
			this.ClipInterface.visible = false;
			this.ClipMonde.visible = false;
			this.$1 = String.fromCharCode(1);
			this.$2 = String.fromCharCode(2);
			this.$3 = String.fromCharCode(3);
			this.$4 = String.fromCharCode(4);
			this.$5 = String.fromCharCode(5);
			this.$6 = String.fromCharCode(6);
			this.$7 = String.fromCharCode(7);
			this.$8 = String.fromCharCode(8);
			this.$11 = String.fromCharCode(11);
			this.$12 = String.fromCharCode(12);
			this.$14 = String.fromCharCode(14);
			this.$15 = String.fromCharCode(15);
			this.$16 = String.fromCharCode(16);
			this.$18 = String.fromCharCode(18);
			this.$20 = String.fromCharCode(20);
			this.$21 = String.fromCharCode(21);
			this.$22 = String.fromCharCode(22);
			this.$24 = String.fromCharCode(24);
			this.$25 = String.fromCharCode(25);
			this.$26 = String.fromCharCode(26);
			this.$27 = String.fromCharCode(27);
			this.ClipJoueurProp = new Box2D.Collision.Shapes.b2CircleDef();
			this.ClipJoueurProp.radius = 0.25;
			this.ClipJoueurProp.density = 2;
			this.ClipJoueurProp.friction = 0.1;
			this.ClipJoueurProp.restitution = 0;
			this.ClipJoueurProp.filter.categoryBits = 2;
			this.ClipJoueurProp.filter.maskBits = 4;
			this.worldAABB = new Box2D.Collision.b2AABB();
			this.worldAABB.lowerBound.Set(-100, -100);
			this.worldAABB.upperBound.Set(100, 100);
			this.MondePhysique = new Box2D.Dynamics.b2World(this.worldAABB, new Box2D.Common.Math.b2Vec2(0, 10), true);
			this.m_iterations = 10;
			this.m_timeStep = 1 / 30;
			stage.addEventListener(flash.events.Event.ENTER_FRAME, this.Boucle_Moteur);
			this.ImagesCalculées = 0;
			this.StyleTexte = new flash.text.StyleSheet();
			this.StyleTexte.setStyle("BV", {"color":"#2F7FCC"});
			this.StyleTexte.setStyle("R", {"color":"#CB546B"});
			this.StyleTexte.setStyle("BL", {"color":"#6C77C1"});
			this.StyleTexte.setStyle("J", {"color":"#BABD2F"});
			this.StyleTexte.setStyle("N", {"color":"#C2C2DA"});
			this.StyleTexte.setStyle("G", {"color":"#606090"});
			this.StyleTexte.setStyle("V", {"color":"#009D9D"});
			this.StyleTexte.setStyle("VP", {"color":"#2ECF73"});
			this.StyleTexte.setStyle("VI", {"color":"#C53DFF"});
			this.StyleTexte.setStyle("ROSE", {"color":"#ED67EA"});
			this.StyleTexte.setStyle("a:hover", {"color":"#2ECF73"});
			this.StyleTexte.setStyle("a:active", {"color":"#2ECF73"});
			this.TimerPosition = new flash.utils.Timer(500);
			this.TimerPosition.addEventListener(flash.events.TimerEvent.TIMER, this.MAJ_Position);
			this.NombreObjet = this.NomObjet.length;
			this.InterfaceListeObjet = new $Liste(145, 189, 43, false);
			this.ClipInterface.addChild(this.InterfaceListeObjet);
			this.InterfaceListeObjet.x = 650;
			this.InterfaceListeObjet.y = 406;
			this.InterfaceListeObjet.Ascenseur();
			this.Domaine = "127.0.0.1";
			this.Version = "0.6";
			this.MauvaiseVersion = true;
			this.Restriction = "^<";
			this.Admin = false;
			this.Modo = false;
			this.SalonCible = "1";
			stage.tabChildren = false;
			flash.system.Security.allowDomain("*");
			try {
				if (ExternalInterface.available) {
					this.Adresse = ExternalInterface.call("window.location.href.toString");
					if (this.Adresse == null) {
						this.SalonCible = "1";
					}
					else {
						this.InfoSalon = this.Adresse.split("?salon=");
						if (this.InfoSalon.length == 1) {
							this.SalonCible = "1";
						}
						else {
							this.SalonCible = this.InfoSalon[1].toLowerCase();
						}
					}
				}
				else {
					this.SalonCible = "1";
				}
			}
			catch (E:Error) { }
			this.BoucleReveille = new flash.utils.Timer(11000);
			this.CE = this.ClipInterface.CE;
			this.LimiteChat = 0;
			this.DernierMessage = "";
			this.TexteChat = this.ClipInterface.CS;
			this.TexteChat.styleSheet = this.StyleTexte;
			this.TexteChat.text = "";
			stage.addEventListener(flash.events.KeyboardEvent.KEY_DOWN, this.Clavier1);
			stage.addEventListener(flash.events.KeyboardEvent.KEY_UP, this.Clavier2);
			this.InterfaceListeJoueur = new $Liste(145, 190, 18, false);
			this.ClipInterface.addChild(this.InterfaceListeJoueur);
			this.InterfaceListeJoueur.x = 497;
			this.InterfaceListeJoueur.y = 406;
			this.InterfaceListeJoueur.Ascenseur();
			this.AscenseurChat = new $Ascenseur(this.TexteChat);
			this.ListeMessage = new Vector.<String>();
			this._Vignette = this.ClipVignette;
			this.AnimVignette = new fl.transitions.Tween(this._Vignette, "alpha", null, 1, 0, 0.1, true);
			this.AnimVignette.addEventListener(fl.transitions.TweenEvent.MOTION_FINISH, this.Fin_AnimVignette);
			this._Vignette.mouseChildren = false;
			this._Vignette.mouseEnabled = false;
			this._Vignette._Texte.styleSheet = this.StyleTexte;
			if (DEBUG) {
				this.Domaine = "127.0.0.1";
				this.Serveur = new XMLSocket(this.Domaine, 59156);
				this.Serveur.addEventListener(Event.CONNECT, this.Connexion);
				this.Serveur.addEventListener(Event.CLOSE, this.Deconnexion);
				this.Serveur.addEventListener(IOErrorEvent.IO_ERROR, this.Connexion_Impossible);
				this.Serveur.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.Connexion_Interdite);
				this.Serveur.addEventListener(DataEvent.DATA, this.Reception);
				this.ClipIdentification.Version.type = TextFieldType.DYNAMIC;
				this.ClipIdentification.Version.selectable = false;
				this._Serveur._Salon.type = TextFieldType.DYNAMIC;
				this._Serveur._Salon.selectable = false;
			}
		}

		public function Clavier1(Event:flash.events.KeyboardEvent):void {
			var KeyCode:int = Event.keyCode;
			if (stage.focus != this.CE) {
				if (this.ClipJoueur && !this.ClipJoueur.Mort) {
					if (KeyCode == 39 && !this.ClipJoueur.DroiteEnCours) {
						this.ClipJoueur.DroiteEnCours = true;
						this.ClipJoueur._P.scaleX = 1;
						this.MAJ_Position();
						return;
					}
					if (KeyCode == 37 && !this.ClipJoueur.GaucheEnCours) {
						this.ClipJoueur.GaucheEnCours = true;
						this.ClipJoueur._P.scaleX = -1;
						this.MAJ_Position();
						return;
					}
					if (KeyCode == 38) {
						if (this.SautDisponible) {
							this.SautDisponible = false;
							this.DernierSaut = flash.utils.getTimer();
							this.ClipJoueur.Physique.m_linearVelocity.y = -5;
							this.ClipJoueur.Physique.WakeUp();
							this.MAJ_Position();
							return;
						}
					}
				}
				if (this.Guide) {
					if (KeyCode == 32) {
						this.Envoie_Serveur(this.$5 + this.$6);
						return;
					}
					if (KeyCode == 88) {
						this.Boucle_Molette_Key(1);
						return;
					}
					if (KeyCode == 90) {
						this.Boucle_Molette_Key(0);
						return;
					}
					if (KeyCode == 67 || KeyCode == 86) {
						if (this.ObjetEnCours) {
							if (KeyCode == 86 && this.AutoClou && this.AutoClouCode == 14) {
								this.Clou_Mouvement();
								return;
							}
							if (KeyCode == 67 && this.AutoClou && this.AutoClouCode == 22) {
								this.Clou_Mouvement();
								return;
							}
							this.AutoClou = !this.AutoClou;
							var Rot:int = this.ObjetEnCours.rotation;
							this.Clique_Placement_Objet(this.ObjetEnCours.Code);
							if (KeyCode != 67) {
								this.AutoClouCode = 14;
							}
							else {
								this.AutoClouCode = 22;
							}
							if (this.AutoClou) {
								this.AutoClouDécalage = 0;
								this.ObjetEnCours.addChild(new (flash.utils.getDefinitionByName("$Objet_"+this.AutoClouCode) as Class)());
								this.VraiLargeur = this.ObjetEnCours.width;
							}
							this.ObjetEnCours.rotation = Rot;
						}
						return;
					}
				}
				if (KeyCode != 13) {
					if (KeyCode == 27) {
						this.Annulation_Placement_Objet();
					}
				}
				else {
					stage.focus = this.CE;
				}
			}
			else if (KeyCode == 13) {
				var Message:String = this.CE.text;
				this.CE.text = "";
				while (Message.substr(0, 1) == " ") {
					Message = Message.substr(1);
				}
				while (Message.charAt((Message.length - 1)) == " ") {
					Message = Message.substr(0, -1);
				}
				if (Message == "") {
					stage.focus = stage;
					return;
				}
				if (flash.utils.getTimer() - this.LimiteChat < 1000 && !this.Admin) {
					this.Message_Chat("Doucement, merci.");
					return;
				}
				if (Message.charAt(0) == "/") {
					this.LimiteChat = flash.utils.getTimer();
					if (Message == "/ram") {
						this.Message_Chat("<BL>VERSION: "+this.Version, "Client");
						this.Message_Chat("<BL>DEBUG: "+DEBUG, "Client");
						try {
							this.Message_Chat("<BL>Total Memory: "+int(flash.system.System.totalMemory), "Client");
							this.Message_Chat("<BL>Private Memory: "+int(flash.system.System.privateMemory), "Client");
						}
						catch (E:Error){}
					}
					this.Envoie_Serveur(this.$6 + this.$26 + this.$1 + Message.substr(1));
					stage.focus = stage;
					return;
				}
				Message = Message.replace(new RegExp("<", "g"), "&lt;");
				if (this.DernierMessage == Message && !this.Admin) {
					this.Message_Chat("Votre dernier message est identique.");
					return;
				}
				this.LimiteChat = flash.utils.getTimer();
				this.DernierMessage = Message;
				this.Envoie_Serveur(this.$6 + this.$6 + this.$1 + Message);
				stage.focus = stage;
			}
		}

		public function Clavier2(Event:flash.events.KeyboardEvent):void {
			this.DernièreAction = flash.utils.getTimer();
			var KeyCode:int = Event.keyCode;
			if (this.ClipJoueur) {
				if (KeyCode != 39) {
					if (KeyCode == 37) {
						this.ClipJoueur.GaucheEnCours = false;
						this.MAJ_Position();
					}
				}
				else {
					this.ClipJoueur.DroiteEnCours = false;
					this.MAJ_Position();
				}
			}
		}

		public function Boucle_Moteur(Event:flash.events.Event) : void {
			if (this.MoteurActif) {
				var Temps:int = getTimer();
				var TempsEnCours:int = (Temps - this.TempsPartieZéro) / 1000;
				if (TempsEnCours != this.TempsEnCours) {
					this.TempsEnCours = TempsEnCours;
					this.ClipInterface._TR.text = "Temps restant\n" + (120 - this.TempsEnCours) + "s";
				}
				if (this.ArrêtDuTempsEnCours) {
					var ArrêtDuTemps:int = 10 - (Temps - this.ArrêtDuTempsZéro) / 1000;
					if (ArrêtDuTemps != this.TADT) {
						this.TADT = ArrêtDuTemps;
						this.TexteArrêtDuTemps.text = "Arête du temps : " + this.TADT + "s";
					}
				}
				var Images:int = (getTimer() - this.TempsZéro) / 33.33;
				if (!this.ArrêtDuTempsEnCours) {
					var Pos:int = 0;
					while (Pos < Images - this.ImagesCalculées) {
						this.MondePhysique.Step(this.m_timeStep, this.m_iterations);
						Pos++;
					}
				}
				this.ImagesCalculées = Images;
				var BodyList:b2Body = this.MondePhysique.m_bodyList;
				while (BodyList) {
					var BodyData:MovieClip = BodyList.m_userData as MovieClip;
					if (BodyData) {
						if (BodyData.DroiteEnCours) {
							if (BodyList.m_linearVelocity.x < 2) {
								BodyList.m_linearVelocity.x = BodyList.m_linearVelocity.x + 0.5;
							}
						}
						else if (BodyData.GaucheEnCours) {
							if (BodyList.m_linearVelocity.x > -2) {
								BodyList.m_linearVelocity.x = BodyList.m_linearVelocity.x - 0.5;
							}
						}
						BodyData.x = BodyList.GetPosition().x * 30;
						BodyData.y = BodyList.GetPosition().y * 30;
						BodyData.rotation = BodyList.GetAngle() * (180 / Math.PI);
					}
					BodyList = BodyList.m_next;
				}
				if (!this.ClipJoueur.Mort && !this.SautDisponible && Temps - this.DernierSaut > 500) {
					if (this.ClipListeMobile.hitTestPoint(this.ClipJoueur.x, this.ClipJoueur.y + 11, true)) {
						this.SautDisponible = true;
					}
					else if (this.ClipListeMobile.hitTestPoint(this.ClipJoueur.x - 2, this.ClipJoueur.y + 11, true)) {
						this.SautDisponible = true;
					}
					else if (this.ClipListeMobile.hitTestPoint(this.ClipJoueur.x + 2, this.ClipJoueur.y + 11, true)) {
						this.SautDisponible = true;
					}
				}
			}
		}

		public function Boucle_Molette(Event:flash.events.MouseEvent):void {
			if (this.ObjetEnCours) {
				var Rot:int = 0;
				if (Event.delta < 0) {
					Rot = -15;
				}
				else {
					Rot = 15;
				}
				this.ObjetEnCours.rotation = this.ObjetEnCours.rotation + Rot;
			}
		}

		public function Boucle_Molette_Key(Type:int):void {
			if (this.ObjetEnCours) {
				var Rot:int = 0;
				if (Type == 0) {
					Rot = -15;
				}
				else {
					Rot = 15;
				}
				this.ObjetEnCours.rotation = this.ObjetEnCours.rotation + Rot;
			}
		}

		public function Boucle_Placement(Event:flash.events.MouseEvent):void {
			this.ObjetEnCours.x = mouseX;
			this.ObjetEnCours.y = mouseY;
			Event.updateAfterEvent();
		}

		public function Boucle_Reveille(Event:flash.events.Event):void {
			this.Envoie_Serveur(this.$4 + this.$2 + this.$1 + (flash.utils.getTimer() - this.TempsZeroBR));
			this.TempsZeroBR = flash.utils.getTimer();
			if (flash.utils.getTimer() - this.DernièreAction > 180000) {
				this.Serveur.close();
				this.Deconnexion(null);
				this.ClipServeur.Texte.text = "\nVous êtes afk depuis trop longtemps :\'(";
			}
		}

		public function Vignette(Clip:Object, Texte:String, Fixe:int=0, X:int=0, Y:int=0, Largeur:int=0):void {
			Clip.mouseEnabled = true;
			Clip.VignetteTexte = Texte;
			Clip.VignetteFixe = Fixe;
			if (Fixe) {
				Clip.VignetteFixeX = X;
				Clip.VignetteFixeY = Y;
			}
			Clip.VignetteLargeur = Largeur;
			Clip.addEventListener(flash.events.MouseEvent.MOUSE_OVER, this.Vignette_RollOver);
			Clip.addEventListener(flash.events.MouseEvent.ROLL_OUT, this.Vignette_Off);
		}

		public function Vignette_On(Event:flash.events.MouseEvent):void {
			this._Vignette.x = mouseX;
			if (this._Vignette.x > this.LimiteX) {
				this._Vignette.x = this.LimiteX;
			}
			this._Vignette.y = mouseY + 22;
			if (this._Vignette.y > this.LimiteY) {
				this._Vignette.y = this.LimiteY;
			}
			Event.updateAfterEvent();
		}

		public function Vignette_Off(Event:flash.events.MouseEvent):void {
			this.AnimVignette.stop();
			this.AnimVignette.begin = this._Vignette.alpha;
			this.AnimVignette.finish = 0;
			this.AnimVignette.start();
		}

		public function Vignette_RollOver(Event:flash.events.MouseEvent) : void {
			stage.removeEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Vignette_On);
			this.VignetteEnCours = Event.currentTarget;
			this._Vignette._Texte.htmlText = this.VignetteEnCours.VignetteTexte;
			if (this.VignetteEnCours.VignetteLargeur == 0) {
				this._Vignette._Texte.wordWrap = false;
				this._Vignette._Texte.width = this._Vignette._Texte.textWidth + 4;
			}
			else {
				this._Vignette._Texte.wordWrap = true;
				this._Vignette._Texte.width = this.VignetteEnCours.VignetteLargeur;
			}
			this._Vignette._Texte.height = this._Vignette._Texte.textHeight + 4;
			var Width:int = this._Vignette._Texte.width + 10;
			var Height:int = this._Vignette._Texte.height + 6;
			this._Vignette.graphics.clear();
			this._Vignette.graphics.beginFill(2236979);
			this._Vignette.graphics.lineStyle(3, 0, 1, true, "normal", null, JointStyle.MITER);
			this._Vignette.graphics.drawRect(0, 0, Width, Height);
			this._Vignette.graphics.endFill();
			if (this.VignetteEnCours.VignetteFixe == 0) {
				this._Vignette.x = mouseX;
				this._Vignette.y = mouseY + 22;
				stage.addEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Vignette_On);
				this.LimiteX = 800 - this._Vignette.width;
				this.LimiteY = 600 - this._Vignette.height;
				if (this._Vignette.x > this.LimiteX) {
					this._Vignette.x = this.LimiteX;
				}
				if (this._Vignette.y > this.LimiteY) {
					this._Vignette.y = this.LimiteY;
				}
			}
			else if (this.VignetteEnCours.VignetteFixe == 1) {
				this._Vignette.x = this.VignetteEnCours.VignetteFixeX;
				this._Vignette.y = this.VignetteEnCours.VignetteFixeY;
			}
			else if (this.VignetteEnCours.VignetteFixe == 2) {
				this._Vignette.x = this.VignetteEnCours.VignetteFixeX;
				this._Vignette.y = int(this.VignetteEnCours.VignetteFixeY - this._Vignette.height);
			}
			else if (this.VignetteEnCours.VignetteFixe == 3) {
				this._Vignette.x = int(this.VignetteEnCours.VignetteFixeX - this._Vignette.width);
				this._Vignette.y = int(this.VignetteEnCours.VignetteFixeY - this._Vignette.height);
			}
			else if (this.VignetteEnCours.VignetteFixe == 10) {
				this._Vignette.x = mouseX;
				this._Vignette.y = mouseY + 22;
				stage.addEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Vignette_On);
				this.LimiteX = 800 - this._Vignette.width;
				this.LimiteY = 600 - this._Vignette.height;
				if (this._Vignette.x > this.LimiteX) {
					this._Vignette.x = this.LimiteX;
				}
				if (this._Vignette.y > this.LimiteY) {
					this._Vignette.y = this.LimiteY;
				}
			}
			this.AnimVignette.stop();
			if (this._Vignette.alpha != 1) {
				this.AnimVignette.begin = this._Vignette.alpha;
				this.AnimVignette.finish = 1;
				this.AnimVignette.start();
			}
			addChild(this._Vignette);
		}

		public function Fin_AnimVignette(Event:flash.events.Event):void {
			if (this._Vignette.alpha == 0) {
				removeChild(this._Vignette);
				stage.removeEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Vignette_On);
			}
		}

		public function Connexion(Event:flash.events.Event):void {
			this.Envoie_Serveur(this.Version);
			this.BoucleReveille.addEventListener(flash.events.TimerEvent.TIMER, this.Boucle_Reveille);
			this.BoucleReveille.start();
			this.TempsZeroBR = flash.utils.getTimer();
			this.ClipIdentification.visible = true;
			this.TexteServeur.visible = false;
		}

		public function Connexion_Impossible(Event:flash.events.Event):void {
			this.ClipServeur.Texte.text = "\nImpossible d\'établir une connexion avec le serveur :\'(";
		}

		public function Connexion_Interdite(Event:flash.events.SecurityErrorEvent):void {
			this.ClipServeur.Texte.text = "\nImpossible d\'établir une connexion avec le serveur :\'(";
		}

		public function Deconnexion(Event:flash.events.Event):void {
			this.MoteurActif = false;
			stage.removeEventListener(flash.events.Event.ENTER_FRAME, this.Boucle_Moteur);
			this.TimerPosition.stop();
			this.BoucleReveille.stop();
			var Pos:int = 0;
			while (Pos < numChildren) {
				getChildAt(Pos).visible = false;
				++Pos;
			}
			if (this.MauvaiseVersion) {
				this.ClipServeur.Texte.text = "\nVotre version du jeu est incorrecte :\'(";
			}
			else {
				this.ClipServeur.Texte.text = "\nLa connexion avec le serveur vient d\'être interrompue :\'(";
			}
			addChild(this.ClipServeur);
			this.ClipServeur.visible = true;
			this.TexteServeur.visible = true;
			this.ClipIdentification.visible = false;
			this.Serveur.removeEventListener(flash.events.Event.CONNECT, this.Connexion);
			this.Serveur.removeEventListener(flash.events.Event.CLOSE, this.Deconnexion);
			this.Serveur.removeEventListener(flash.events.IOErrorEvent.IO_ERROR, this.Connexion_Impossible);
			this.Serveur.removeEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, this.Connexion_Interdite);
			this.Serveur.removeEventListener(flash.events.DataEvent.DATA, this.Reception);
		}

		public function Envoie_Serveur(Data:String):void {
			this.Serveur.send(Data);
		}

		public function Envoie_Exception(err:Error):void {
			this.Envoie_Serveur(this.$26 + this.$25 + this.$1 + err.getStackTrace());
		}

		public function Reception(Event:flash.events.DataEvent):void {
			var Values:Array = Event.data.split(this.$1);
			var C:int = Values[0].charCodeAt(0);
			var CC:int = Values[0].charCodeAt(1);
			if (C == 4) {
				if (CC == 3) {
					if (!this.Synchroniseur && !this.ArrêtDuTempsEnCours) {
						Values.shift();
						var Pos43:int = 0;
						while (Pos43 < Values.length) {
							var Objet:String = Values[Pos43];
							var Mobile:b2Body = this.ListeMobile[Pos43];
							if (Objet != "x") {
								var ObjetData:Array = Objet.split(",");
								if (!Mobile) {
									Mobile = this.Creation_Objet(ObjetData[0], 0, 0, 0);
								}
								Mobile.SetXForm(new Box2D.Common.Math.b2Vec2(ObjetData[1], ObjetData[2]), ObjetData[5]);
								var vX:Number = Number(ObjetData[3]);
								var vY:Number = Number(ObjetData[4]);
								Mobile.SetLinearVelocity(new Box2D.Common.Math.b2Vec2(vX, vY));
								var vAngle:Number = Number(ObjetData[6]);
								Mobile.SetAngularVelocity(vAngle);
								if (vX < 0.01 && -0.01 < vX && vY < 0.01 && -0.01 < vY && vAngle < 0.01 && -0.01 < vAngle) {
									Mobile.PutToSleep();
								}
							}
							else if (Mobile) {
								this.Destruction_Mobile(Pos43);
							}
							++Pos43;
						}
					}
					return;
				}
				if (CC == 4) {
					var Joueur44:Poisson = this.ListeJoueur[int(Values[7])];
					if (Joueur44 && !Joueur44.ClipJoueur) {
						Joueur44.DroiteEnCours = Values[1] == "1";
						Joueur44.GaucheEnCours = Values[2] == "1";
						var JoueurPhys:b2Body = Joueur44.Physique;
						JoueurPhys.SetXForm(new Box2D.Common.Math.b2Vec2(Values[3], Values[4]), 0);
						JoueurPhys.SetLinearVelocity(new Box2D.Common.Math.b2Vec2(Values[5], Values[6]));
						if (Joueur44.DroiteEnCours) {
							Joueur44._P.scaleX = 1;
						}
						else if (Joueur44.GaucheEnCours) {
							Joueur44._P.scaleX = -1;
						}
					}
					return;
				}
				if (CC == 20) {
					this.Envoie_Serveur(this.$4 + this.$20);
					return;
				}
			}
			if (C == 5) {
				if (CC == 5) {
					if (this.TexteArrêtDuTemps.parent) {
						this.ClipInterface.removeChild(this.TexteArrêtDuTemps);
					}
					this.TADT = 0;
					this.ArrêtDuTempsEnCours = false;
					this.Nouvelle_Partie(Values[1]);
					this.ClipInterface._JEV.text = "Joueurs\nen vie : " + Values[2];
					return;
				}
				if (CC == 6) {
					if (Values.length != 1) {
						if (this.TexteArrêtDuTemps.parent) {
							this.ClipInterface.removeChild(this.TexteArrêtDuTemps);
						}
						this.TADT = 0;
						this.ArrêtDuTempsEnCours = false;
					}
					else  {
						this.ClipInterface.addChild(this.TexteArrêtDuTemps);
						this.ArrêtDuTempsEnCours = true;
						this.ArrêtDuTempsZéro = flash.utils.getTimer();
					}
					return;
				}
				if (CC == 7) {
					var Pos57:int = 1;
					while (Pos57 < Values.length) {
						this.Création_Lien.apply(this, Values[Pos57].split(","));
						++Pos57;
					}
					return;
				}
				if (CC == 20) {
					if (!this.Guide) {
						this.Creation_Objet(Values[1], Values[2], Values[3], Values[4]);
					}
					return;
				}
				if (CC == 21) {
					this.Message_Chat("Vous venez d\'entrer dans le salon [" + Values[1] + "].");
					return;
				}
			}
			if (C == 6) {
				if (CC == 6) {
					if (Values[2].indexOf("<") != -1) {
						return;
					}
					this.Message_Chat(Values[2], Values[1]);
					return;
				}
				if (CC == 20) {
					this.Message_Chat("<BL>" + Values[1], "Serveur");
					return;
				}
			}
			if (C == 8) {
				if (CC == 5) {
					this.Destruction_Joueur(Values[1], 1, Values[3]);
					this.MAJ_InterfaceListeJoueur();
					this.ClipInterface._JEV.text = "Joueurs\nen vie : " + Values[2];
					return;
				}
				if (CC == 6) {
					this.Destruction_Joueur(Values[1], 2, Values[3]);
					this.MAJ_InterfaceListeJoueur();
					this.ClipInterface._JEV.text = "Joueurs\nen vie : " + Values[2];
					return;
				}
				if (CC == 7) {
					this.Destruction_Joueur(Values[1]);
					this.Message_Chat(Values[2] + " vient de se déconnecter.");
					this.MAJ_InterfaceListeJoueur();
					return;
				}
				if (CC == 8) {
					var Infos:Array = Values[1].split(",");
					var JoueurClip:MovieClip = this.Creation_Joueur(Infos);
					this.Message_Chat(Infos[0] + " vient de se connecter.");
					if (!JoueurClip.Mort) {
						this.ClipListeJoueur.addChild(JoueurClip);
					}
					this.MAJ_InterfaceListeJoueur();
					return;
				}
				if (CC == 9) {
					Values.shift();
					this.Chargement_Liste_Joueur(Values);
					this.MAJ_InterfaceListeJoueur();
					return;
				}
				if (CC == 20) {
					this.Guide = false;
					try {
						var Joueur820:Poisson = this.ListeJoueur[int(Values[1])];
						this.ClipInterface._G.text = Joueur820.NomJoueur;
						this.NomGuide = Joueur820.NomJoueur;
						if (Joueur820.ClipJoueur) {
							this.Guide = true;
							this.Message_Chat("<VI>VOUS ÊTES LE POISSONNIER ! ATTRAPEZ LES TOUUUS !");
						}
						else  {
							this.Message_Chat("<J>" + Joueur820.NomJoueur + " est maintenant votre poissonnier !");
						}
						this.Init_Guide(this.Guide);
						this.MAJ_InterfaceListeJoueur();
					}
					catch (E:Error) {}
					return;
				}
				if (CC == 21) {
					this.Synchroniseur = false;
					if (int(Values[1]) == this.CodeJoueur) {
						this.Synchroniseur = true;
					}
					return;
				}
			}
			if (C == 26) {
				if (CC == 4) {
					this.Message_Chat(Values[1], null, true);
					return;
				}
				if (CC == 8) {
					this.NomJoueur = Values[1];
					this.CodeJoueur = int(Values[2]);
					return;
				}
				if (CC == 22) {
					return; //In loader.
				}
				if (CC == 25) {
					this.Message_Chat("\n" + Values[2] + "\n<J>Exception pour [" + Values[1] + "]\n");
					return;
				}
				if (CC == 26) {
					return; //In loader.
				}
				if (CC == 27) {
					this.MauvaiseVersion = false;
					this.ClipIdentification.Version.text = "Version " + this.Version;
					this.TexteServeur.text = "\nChargement en cours.";
					return;
				}
			}
			trace("Code inconnu : " + C + " -> " + CC);
			return;
		}

		public function MAJ_Position(Event:flash.events.Event=null):void {
			if (Event && this.Synchroniseur) {
				var Data:String = this.$4 + this.$3;
				var Pos:int = 0;
				while (Pos < this.ListeMobile.length) {
					var Mobile:b2Body = this.ListeMobile[Pos];
					if (Mobile) {
						var MobileXF:Box2D.Common.Math.b2XForm = Mobile.GetXForm();
						var MobileX:Number = int(MobileXF.position.x * 1000) / 1000;
						var MobileY:Number = int(MobileXF.position.y * 1000) / 1000;
						if (-4 > MobileX || MobileX > 31 || MobileY > 15 || -15 > MobileY) {
							this.Destruction_Mobile(Pos);
							Data = Data + this.$1 + "x";
						}
						else {
							var MobileVelocity:b2Vec2 = Mobile.GetLinearVelocity();
							Data = Data + this.$1 + int(Mobile.m_userData.Type) + "," + MobileX + "," + MobileY + "," + (int(MobileVelocity.x * 1000) / 1000) + 
								"," + (int(MobileVelocity.y * 1000) / 1000) + "," + (int(Mobile.GetAngle() * 1000) / 1000) + "," + (int(Mobile.GetAngularVelocity() * 1000) / 1000);
						}
					}
					else {
						Data = Data + this.$1 + "x";
					}
					++Pos;
				}
				this.Envoie_Serveur(Data);
			}
			if (!this.ClipJoueur.Mort) {
				var Physique:b2Body = this.ClipJoueur.Physique;
				var Droite:int = this.ClipJoueur.DroiteEnCours ? 1 : 0;
				var Gauche:int = this.ClipJoueur.GaucheEnCours ? 1 : 0;
				var XForm:Box2D.Common.Math.b2XForm = Physique.GetXForm();
				var Velocity:b2Vec2 = Physique.GetLinearVelocity();
				this.Envoie_Serveur(this.$4 + this.$4 + this.$1 + Droite + this.$1 + Gauche + this.$1 + int(XForm.position.x * 1000) / 1000 + this.$1 + 
					int(XForm.position.y * 1000) / 1000 + this.$1 + int(Velocity.x * 1000) / 1000 + this.$1 + int(Velocity.y * 1000) / 1000);
			}
		}

		public function MAJ_AutoClou():void {
			(this.ObjetEnCours.getChildAt(this.ObjetEnCours.numChildren - 1) as flash.display.MovieClip).x = this.AutoClouDécalage;
		}

		public function MAJ_ListeJoueur():void {
			return;
		}

		public function MAJ_InterfaceListeJoueur():void {
			this.InterfaceListeJoueur.Vider();
			for each (var Joueur:Poisson in this.ListeJoueur) {
				var Element:$NomJoueur = new $NomJoueur();
				Element.Score = Joueur.Score;
				Element._N.mouseEnabled = false;
				Element._N.styleSheet = this.StyleTexte;
				if (Joueur.ClipJoueur) {
					Element._N.htmlText = "<V>" + Joueur.NomJoueur + " <J>" + Joueur.Score;
				}
				else if (this.NomGuide != Joueur.NomJoueur) {
					if (Joueur.Mort) {
						Element._N.htmlText = "<R>" + Joueur.NomJoueur + " <J>" + Joueur.Score;
					}
					else {
						Element._N.htmlText = Joueur.NomJoueur + " <J>" + Joueur.Score;
					}
				}
				else {
					Element._N.htmlText = "<VI>" + Joueur.NomJoueur + " <J>" + Joueur.Score;
				}
				this.InterfaceListeJoueur.Ajout_Element(Element);
			}
			this.InterfaceListeJoueur.Rendu("Score", Array.NUMERIC | Array.DESCENDING);
			this.InterfaceListeJoueur.Position(1);
		}

		public function Chargement_Liste_Joueur(Liste:Array):void {
			for each (var Joueur:MovieClip in this.ListeJoueur) {
				this.MondePhysique.DestroyBody(Joueur.Physique);
			}
			while (this.ClipListeJoueur.numChildren) {
				this.ClipListeJoueur.removeChildAt(0);
			}
			this.ListeJoueur = new flash.utils.Dictionary();
			if (this.ClipJoueur) {
				this.ClipJoueur.DroiteEnCours = false;
				this.ClipJoueur.GaucheEnCours = false;
			}
			for each (var Infos:String in Liste) {
				var NouveauJoueur:MovieClip = this.Creation_Joueur(Infos.split(","));
				if (!NouveauJoueur.Mort) {
					this.ClipListeJoueur.addChild(NouveauJoueur);
				}
			}
			if (this.ClipJoueur && !this.ClipJoueur.Mort) {
				this.ClipListeJoueur.addChild(this.ClipJoueur);
			}
		}

		public function Creation_Joueur(Infos:Array):flash.display.MovieClip {
			var JoueurBody:b2BodyDef = new Box2D.Dynamics.b2BodyDef();
			JoueurBody.position.x = this.Monde.PosX;
			JoueurBody.position.y = this.Monde.PosY;
			JoueurBody.fixedRotation = true;
			var Joueur:Poisson = new Poisson();
			Joueur._N.text = Infos[0];
			Joueur.Mort = Infos[2] == "1";
			Joueur.CodeJoueur = int(Infos[1]);
			Joueur.NomJoueur = Infos[0];
			Joueur.Score = int(Infos[3]);
			JoueurBody.userData = Joueur;
			if (int(Infos[1]) == this.CodeJoueur) {
				this.ClipJoueur = Joueur;
				Joueur.ClipJoueur = true;
				Joueur._N.textColor = 12763866;
			}
			var MondeBody:b2Body = this.MondePhysique.CreateBody(JoueurBody);
			MondeBody.CreateShape(this.ClipJoueurProp);
			var MassData:b2MassData = new Box2D.Collision.Shapes.b2MassData();
			MassData.mass = 100;
			MondeBody.SetMass(MassData);
			if (int(Infos[1]) == this.CodeJoueur) {
				MondeBody.AllowSleeping(false);
			}
			this.ListeJoueur[int(Infos[1])] = Joueur;
			Joueur.Physique = MondeBody;
			return Joueur;
		}

		public function Destruction_Joueur(Pos:int, Type:int=0, Score:int=0):void {
			var Joueur:Poisson = this.ListeJoueur[Pos];
			if (Joueur) {
				if (Type == 0) {
					delete this.ListeJoueur[Pos];
				}
				if (Joueur.parent) {
					Joueur.parent.removeChild(Joueur);
					this.MondePhysique.DestroyBody(Joueur.Physique);
				}
				Joueur.Mort = true;
				Joueur.Score = Score;
				if (Joueur.ClipJoueur) {
					if (Type == 1) {
						this.Message_Chat("Hahah, poisson pas frais !");
					}
					else if (Type == 2) {
						this.Message_Chat("Ouf, vous êtes encore frais.");
					}
				}
			}
		}

		public function Message_Chat(Message:String, NomJoueur:String=null, Serveur:Boolean=false):void {
			if (NomJoueur != null) {
				if (this.NomGuide != NomJoueur) {
					Message = "<V>[" + NomJoueur + "] <N>" + Message;
				}
				else {
					Message = "<V>[" + NomJoueur + "] <R>" + Message;
				}
			}
			else if (Serveur) {
				Message = "<ROSE>[*] [Serveur] " + Message;
			}
			else {
				Message = "<font color=\'#7A7B96\'>" + Message + "</font>";
			}
			if (this.ListeMessage.length > 150) {
				this.ListeMessage.shift();
			}
			this.ListeMessage.push(Message);
			this.TexteChat.htmlText = this.ListeMessage.join("\n");
			if (this.TexteChat.scrollV == this.TexteChat.maxScrollV) {
				this.AscenseurChat.Rendu_Ascenseur(2);
			}
			else {
				this.AscenseurChat.Rendu_Ascenseur(1);
			}
		}

		public function Initialisation_Base(Monde:flash.display.MovieClip):void {
			var BodyDef:*=new Box2D.Dynamics.b2BodyDef();
			BodyDef.position.Set(0, 0);
			var MondeBase:*=new $Monde__Base();
			BodyDef.userData = MondeBase;
			MondeBase.mouseChildren = false;
			MondeBase.mouseEnabled = false;
			this.PhysiqueSol = this.MondePhysique.CreateBody(BodyDef);
			this.PhysiqueSol.CreateShape(this.Mobile_Statique(MondeBase, new Array(0, 350, 100, 350, 100, 420, 0, 420)));
			this.ClipListeMobile.addChild(Monde);
			this.ClipListeMobile.addChild(BodyDef.userData);
			var NumChildren:int = Monde.numChildren;
			var Pos:int = 0;
			while (Pos < NumChildren)  {
				var Obj:MovieClip = Monde.getChildAt(Pos) as flash.display.MovieClip;
				if (Obj) {
					if (Obj.name != "m") {
						if (Obj.name == "M") {
							this.PhysiqueSol.CreateShape(this.Mobile_Statique(null, new Array(Obj.x, Obj.y, Obj.x + Obj.width, Obj.y, Obj.x + Obj.width, 
								Obj.y + Obj.height, Obj.x, Obj.y + Obj.height)));
						}
					}
					else {
						this.PhysiqueSol.CreateShape(this.Mobile_Statique(MondeBase, new Array(Obj.x, Obj.y, Obj.x + Obj.width, Obj.y, Obj.x + Obj.width, 
								Obj.y + Obj.height, Obj.x, Obj.y + Obj.height)));
						Monde.removeChild(Obj);
						--Pos;
						--NumChildren;
					}
				}
				++Pos;
			}
			this.PhysiqueSol.CreateShape(this.Mobile_Statique(null, new Array(720, 50, 800, 50, 800, 410, 720, 410)));
			this.PhysiqueSol.SetMassFromShapes();
			this.PhysiqueSol = this.MondePhysique.CreateBody(BodyDef);
		}

		public function Création_Clou(Type:int, pX:int, pY:int):void {
			var ListeMobileHit:Array = new Array();
			var Pos:int = 0;
			while (Pos < this.ListeMobile.length) {
				var Mobile:b2Body = this.ListeMobile[Pos];
				if (Mobile) {
					var MobileData:MovieClip = Mobile.m_userData as flash.display.MovieClip;
					if (!((Type == 11 || Type == 12 || Type == 13) && MobileData.Sol)) {
						if (MobileData.hitTestPoint(pX, pY, true)) {
							ListeMobileHit.push(Mobile);
						}
					}
				}
				++Pos;
			}
			var Démarrer:int = 0;
			if (ListeMobileHit.length == 0) {
				return;
			}
			var PrevObj:b2Body = null;
			if (Type == 11 || Type == 12 || Type == 13) {
				PrevObj = this.PhysiqueSol;
			}
			else {
				if (ListeMobileHit.length == 1) {
					return;
				}
				PrevObj = ListeMobileHit[0];
				Démarrer = 1;
			}
			if (ListeMobileHit.length) {
				var Data:String = this.$5 + this.$7;
				var Point:b2Vec2 = new Box2D.Common.Math.b2Vec2(pX / 30, pY / 30);
				Pos = Démarrer;
				while (Pos < ListeMobileHit.length) {
					var Objet1:b2Body = ListeMobileHit[Pos];
					var Objet1P:b2Vec2 = Objet1.GetLocalPoint(Point);
					var Objet1X:Number = int(Objet1P.x * 1000) / 1000;
					var Objet1Y:Number = int(Objet1P.y * 1000) / 1000;
					var Objet1Rot:Number = int(Objet1.GetAngle() * 1000) / 1000;
					var Objet1L:int = 0;
					if (Objet1 != this.PhysiqueSol) {
						Objet1L = this.ListeMobile.indexOf(Objet1);
					}
					else {
						Objet1L = -2;
					}
					var Objet2:b2Vec2 = PrevObj.GetLocalPoint(Point);
					var Objet2X:Number = int(Objet2.x * 1000) / 1000;
					var Objet2Y:Number = int(Objet2.y * 1000) / 1000;
					var Objet2Rot:Number = int(PrevObj.GetAngle() * 1000) / 1000;
					var Objet2L:int = 0;
					if (PrevObj != this.PhysiqueSol) {
						Objet2L = this.ListeMobile.indexOf(PrevObj);
					}
					else {
						Objet2L = -2;
					}
					Data = Data + this.$1 + Type + "," + Objet1L + "," + Objet1X + "," + Objet1Y + "," + Objet1Rot + "," + Objet2L + "," + Objet2X + "," + Objet2Y + "," + Objet2Rot;
					PrevObj = Objet1;
					++Pos;
				}
				this.Envoie_Serveur(Data);
			}
		}

		public function Clou_Mouvement():void {
			if (this.AutoClouDécalage < 0) {
				this.AutoClouDécalage = 0;
			}
			else if (this.AutoClouDécalage != 0) {
				this.AutoClouDécalage = -int(this.VraiLargeur / 2 - 5);
			}
			else {
				this.AutoClouDécalage = int(this.VraiLargeur / 2 - 5);
			}
			this.MAJ_AutoClou();
		}

		public function Création_Lien(Type:int, Objet1:int, Objet1X:Number, Objet1Y:Number, Objet1Rot:Number, 
									  Objet2:int, Objet2X:Number, Objet2Y:Number, Objet2Rot:Number):void {
			var Objet1Body:*=null;
			var Objet2Body:*=null;
			if (Objet1 != -2) {
				Objet1Body = this.ListeMobile[Objet1];
			}
			else {
				Objet1Body = this.PhysiqueSol;
			}
			if (Objet2 != -2) {
				Objet2Body = this.ListeMobile[Objet2];
			}
			else {
				Objet2Body = this.PhysiqueSol;
			}
			if (Objet1Body && Objet2Body) {
				var JointDef:b2RevoluteJointDef = new Box2D.Dynamics.Joints.b2RevoluteJointDef();
				if (!(Objet1 == -2) && !(Objet2 == -2) && (Type == 11 || Type == 12 || Type == 13) || Type == 22) {
					JointDef.enableLimit = true;
					if (Type != 22) {
						JointDef.lowerAngle = 0;
						JointDef.upperAngle = 0;
					}
					else {
						JointDef.lowerAngle = -0.1;
						JointDef.upperAngle = 0.1;
					}
				}
				else if (Objet1 != -2) {
					Objet1Body.m_userData.Sol = true;
				}
				else {
					Objet2Body.m_userData.Sol = true;
				}
				JointDef.body1 = Objet1Body;
				JointDef.body2 = Objet2Body;
				JointDef.localAnchor1 = new Box2D.Common.Math.b2Vec2(Objet1X, Objet1Y);
				JointDef.localAnchor2 = new Box2D.Common.Math.b2Vec2(Objet2X, Objet2Y);
				JointDef.referenceAngle = Objet2Rot - Objet1Rot;
				if (Type == 12 || Type == 15) {
					JointDef.enableMotor = true;
					JointDef.motorSpeed = -0.2;
					JointDef.maxMotorTorque = 1000000;
				}
				else if (Type == 13 || Type == 16) {
					JointDef.enableMotor = true;
					JointDef.motorSpeed = 0.2;
					JointDef.maxMotorTorque = 1000000;
				}
				this.MondePhysique.CreateJoint(JointDef);
				if (!Objet1Body.m_userData.Lien) {
					var Objet:* = new (flash.utils.getDefinitionByName("$Objet_"+Type) as Class)();
					if (Type == 11 || Type == 12 || Type == 13) {
						Objet1Body.m_userData.Lien = true;
					}
					Objet1Body.m_userData.addChild(Objet);
					Objet.x = Objet1X * 30;
					Objet.y = Objet1Y * 30;
				}
				Objet1Body.WakeUp();
				Objet2Body.WakeUp();
			}
		}

		public function Mobile_Statique(MondeUserData:flash.display.MovieClip, SolArray:Array):Box2D.Collision.Shapes.b2PolygonDef {
			var polyDef:b2PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
			polyDef.vertexCount = SolArray.length / 2;
			polyDef.filter.categoryBits = 4;
			polyDef.friction = 0.3;
			polyDef.density = 0;
			if (MondeUserData) {
				MondeUserData.graphics.lineStyle(2);
				MondeUserData.graphics.beginFill(737332);
			}
			var PolyPos:int = 0;
			var Pos:int = 0;
			while (Pos < SolArray.length) {
				var X:int = SolArray[Pos];
				var Y:int = SolArray[Pos + 1];
				polyDef.vertices[PolyPos].Set(X / 30, Y / 30);
				if (MondeUserData) {
					if (Pos != 0) {
						MondeUserData.graphics.lineTo(X, Y);
					}
					else {
						MondeUserData.graphics.moveTo(X, Y);
					}
				}
				++PolyPos;
				Pos = Pos + 2;
			}
			if (MondeUserData) {
				MondeUserData.graphics.endFill();
			}
			return polyDef;
		}

		public function Destruction_Mobile(Pos:int):void {
			var Mobile:b2Body = this.ListeMobile[Pos];
			if (Mobile) {
				this.ListeMobile[Pos] = null;
				if (Mobile.m_userData.parent) {
					Mobile.m_userData.parent.removeChild(Mobile.m_userData);
				}
				this.MondePhysique.DestroyBody(Mobile);
			}
		}

		public function Nouvelle_Partie(Num:int):void {
			this.ClipServeur.visible = false;
			this.ClipInterface.visible = true;
			this.ClipMonde.visible = true;
			this.TempsPartieZéro = flash.utils.getTimer();
			while (this.ClipListeMobile.numChildren) {
				this.ClipListeMobile.removeChildAt(0);
			}
			var BodyList:Array = new Array();
			var MondeBodyList:b2Body = this.MondePhysique.m_bodyList;
			while (MondeBodyList) {
				BodyList.push(MondeBodyList);
				MondeBodyList = MondeBodyList.m_next;
			}
			var i:int = 0;
			while (i < BodyList.length) {
				this.MondePhysique.DestroyBody(BodyList[i]);
				++i;
			}
			this.worldAABB = new Box2D.Collision.b2AABB();
			this.worldAABB.lowerBound.Set(-100, -100);
			this.worldAABB.upperBound.Set(100, 100);
			this.MondePhysique = new Box2D.Dynamics.b2World(this.worldAABB, new Box2D.Common.Math.b2Vec2(0, 10), true);
			this.Monde = new (flash.utils.getDefinitionByName("$Monde_"+Num) as Class)();
			this.ListeMobile = new Array();
			this.Monde.Initialisation(this, this.ClipListeMobile);
			this.TempsZéro = flash.utils.getTimer();
			this.TimerPosition.start();
			this.MoteurActif = true;
		}

		public function Init_Guide(isGuide:Boolean) : void {
			if (isGuide) {
				this.AutoClou = false;
				this.ClipInterface.addChild(this.TexteArrêtDuTemps);
				this.TexteArrêtDuTemps.text = "Appuyez sur ESPACE pour\ndéclencher une arête du temps !";
				this.InterfaceListeObjet.Vider();
				var ListeObjet:Array = this.ListeObjetDispo.slice();
				var Pos:int = 0;
				if (this.Monde.ObjetInterdit) {
					while (Pos < this.Monde.ObjetInterdit.length) {
						var Pos2:int = 0;
						while (Pos2 < ListeObjet.length) {
							if (ListeObjet[Pos2] == this.Monde.ObjetInterdit[Pos]) {
								ListeObjet.splice(Pos2, 1);
								break;
							}
							Pos2++;
						}
						Pos++;
					}
				}
				Pos = 0;
				while (Pos < ListeObjet.length) {	
					var Objet1Code:int = ListeObjet[Pos];
					var Objet2Code:int = ListeObjet[(Pos + 1)];
					var Objet1:MovieClip = new (this.loaderInfo.applicationDomain.getDefinition("$Objet_" + Objet1Code) as Class)();
					var Objet2:MovieClip = new (this.loaderInfo.applicationDomain.getDefinition("$Objet_" + Objet2Code) as Class)();
					if (Pos == 0) {
						Objet1.gotoAndStop(14);
					}
					var Element:MovieClip = new $ObjetInterface();
					Element._O1.addChild(Objet1);
					if (Objet2Code) {
						Element._O2.addChild(Objet2);
					}
					Element.x = 2;
					Element._O1.buttonMode = true;
					Element._O1.useHandCursor = true;
					Element._O1.mouseChildren = false;
					Element._O2.buttonMode = true;
					Element._O2.useHandCursor = true;
					Element._O2.mouseChildren = false;
					Element._O1.Code = Objet1Code;
					Element._O2.Code = Objet2Code;
					Objet1.x = 32;
					Objet1.y = 20;
					Objet2.x = 32;
					Objet2.y = 20;
					if (Objet1.height > 36) {
						Objet1.width = Objet1.width * (36 / Objet1.height);
						Objet1.height = 36;
					}
					if (Objet1.width > 61) {
						Objet1.height = Objet1.height * (61 / Objet1.width);
						Objet1.width = 61;
					}
					if (Objet2Code) {
						if (Objet2.height > 36) {
							Objet2.width = Objet2.width * (36 / Objet2.height);
							Objet2.height = 36;
						}
						if (Objet2.width > 61) {
							Objet2.height = Objet2.height * (61 / Objet2.width);
							Objet2.width = 61;
						}
					}
					Element._O1.addEventListener(MouseEvent.MOUSE_DOWN, this.Clique_Guide);
					if (Objet2Code) {
						Element._O2.addEventListener(MouseEvent.MOUSE_DOWN, this.Clique_Guide);
					}
					this.Vignette(Element._O1, this.NomObjet[Objet1Code]);
					if (Objet2Code) {
						this.Vignette(Element._O2, this.NomObjet[Objet2Code]);
					}
					this.InterfaceListeObjet.Ajout_Element(Element);
					Pos = Pos + 2;
				}
				this.InterfaceListeObjet.Rendu();
			}
			else {
				this.Annulation_Placement_Objet();
				this.InterfaceListeObjet.Vider();
				if (this.TexteArrêtDuTemps.parent) {
					this.ClipInterface.removeChild(this.TexteArrêtDuTemps);
				}
			}
			this.InterfaceListeObjet.Position(0);
		}

		public function Clique_Guide(Event:flash.events.MouseEvent):void {
			this.AutoClou = false;
			this.Clique_Placement_Objet((Event.currentTarget as flash.display.MovieClip).Code);
		}

		public function Creation_Objet(Code:int, pX:int, pY:int, Rot:int):Box2D.Dynamics.b2Body {
			var Body:b2Body;
			var MassData:b2MassData;
			var CircleDef:b2CircleDef;
			var PolygonDef:b2PolygonDef;
			var BodyDef:b2BodyDef = new Box2D.Dynamics.b2BodyDef();
			BodyDef.position.x = pX / 30;
			BodyDef.position.y = pY / 30;
			BodyDef.angle = Math.PI * Rot / 180;
			var hx:Number = 0;
			var hy:Number = 0;
			var Objet:* = new (this.loaderInfo.applicationDomain.getDefinition("$Objet_" + Code) as Class)();
			Objet.Type = Code;
			if (Code == 0) {
				this.ClipListeMobile.addChild(Objet);
				Objet.x = pX;
				Objet.y = pY;
				Objet.rotation = Rot;
				return null;
			}
			if (Code == 1 || Code == 2) {
				if (Code != 1) {
					hx = 1;
					hy = 1;
				}
				else {
					hx = 0.5;
					hy = 0.5;
				}
				PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
				PolygonDef.filter.categoryBits = 4;
				PolygonDef.SetAsBox(hx, hy);
				PolygonDef.density = 30;
				PolygonDef.friction = 0.8;
				PolygonDef.restitution = 0.2;
				BodyDef.userData = Objet;
				Objet.width = hx * 60;
				Objet.height = hy * 60;
				Body = this.MondePhysique.CreateBody(BodyDef);
				Body.CreateShape(PolygonDef);
				Body.SetMassFromShapes();
			}
			else if (Code == 3 || Code == 4) {
				if (Code != 3) {
					hx = 3.33;
				}
				else {
					hx = 1.66;
				}
				hy = 0.16666;
				PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
				PolygonDef.filter.categoryBits = 4;
				PolygonDef.SetAsBox(hx, hy);
				PolygonDef.density = 50;
				PolygonDef.friction = 0.3;
				PolygonDef.restitution = 0;
				BodyDef.userData = Objet;
				Body = this.MondePhysique.CreateBody(BodyDef);
				Body.CreateShape(PolygonDef);
				Body.SetMassFromShapes();
			}
			else if (Code == 5 || Code == 6) {
				hx = 0.5;
				hy = 0.5;
				CircleDef = new Box2D.Collision.Shapes.b2CircleDef();
				CircleDef.filter.categoryBits = 4;
				CircleDef.radius = hx;
				if (Code != 5) {
					CircleDef.density = 10;
				}
				else {
					CircleDef.density = 100;
				}
				CircleDef.friction = 0;
				CircleDef.restitution = 0.2;
				BodyDef.userData = Objet;
				Body = this.MondePhysique.CreateBody(BodyDef);
				Body.CreateShape(CircleDef);
				if (Code != 5) {
					Body.SetMassFromShapes();
				}
				else {
					MassData = new Box2D.Collision.Shapes.b2MassData();
					MassData.mass = 500;
					Body.SetMass(MassData);
				}
			}
			else if (Code != 7) {
				if (Code == 8 || Code == 9) {
					if (Code != 8) {
						hx = 3.33;
					}
					else {
						hx = 1.66;
					}
					hy = 0.166;
					PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
					PolygonDef.filter.categoryBits = 4;
					PolygonDef.SetAsBox(hx, hy);
					PolygonDef.density = 20;
					PolygonDef.friction = 10;
					BodyDef.userData = Objet;
					Objet.width = hx * 60;
					Body = this.MondePhysique.CreateBody(BodyDef);
					Body.CreateShape(PolygonDef);
					Body.SetMassFromShapes();
				}
				else if (Code != 10) {
					if (Code > 16 && Code < 21) {
						hx = 0.5;
						hy = 0.5;
						CircleDef = new Box2D.Collision.Shapes.b2CircleDef();
						CircleDef.filter.categoryBits = 4;
						CircleDef.radius = hx;
						CircleDef.density = 1;
						CircleDef.friction = 0.2;
						CircleDef.restitution = 0.2;
						BodyDef.userData = Objet;
						Body = this.MondePhysique.CreateBody(BodyDef);
						Body.CreateShape(CircleDef);
						MassData = new Box2D.Collision.Shapes.b2MassData();
						MassData.mass = 1000;
						if (Code == 17) {
							Body.m_linearVelocity.y = -20;
						}
						else if (Code == 18) {
							Body.m_linearVelocity.y = 10;
							MassData.mass = 2000;
						}
						else if (Code == 19) {
							Body.m_linearVelocity.x = 20;
						}
						else if (Code == 20) {
							Body.m_linearVelocity.x = -20;
						}
						MassData.center = new Box2D.Common.Math.b2Vec2(0, 0);
						MassData.I = 100;
						Body.SetMass(MassData);
					}
					else if (Code == 21) {
						hx = 0.5;
						hy = 0.5;
						CircleDef = new Box2D.Collision.Shapes.b2CircleDef()
						CircleDef.filter.categoryBits = 4;
						CircleDef.radius = hx;
						CircleDef.density = 100;
						CircleDef.friction = 30;
						CircleDef.restitution = 0;
						BodyDef.userData = Objet;
						Body = this.MondePhysique.CreateBody(BodyDef);
						Body.CreateShape(CircleDef);
						MassData = new Box2D.Collision.Shapes.b2MassData();
						MassData.mass = 500;
						Body.SetMass(MassData);
					}
				}
				else {
					hx = 0.5;
					hy = 0.5;
					PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
					PolygonDef.filter.categoryBits = 4;
					PolygonDef.SetAsBox(hx, hy);
					PolygonDef.density = 50;
					PolygonDef.friction = 0.2;
					PolygonDef.restitution = 0;
					BodyDef.userData = Objet;
					Objet.width = hx * 60;
					Objet.height = hy * 60;
					Body = this.MondePhysique.CreateBody(BodyDef);
					Body.CreateShape(PolygonDef);
					MassData = new Box2D.Collision.Shapes.b2MassData();
					MassData.mass = 1000;
					MassData.center = new Box2D.Common.Math.b2Vec2(0, 0);
					MassData.I = 100;
					Body.SetMass(MassData);
				}
			}
			else {
				BodyDef.userData = Objet;
				Body = this.MondePhysique.CreateBody(BodyDef);
				PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
				PolygonDef.filter.categoryBits = 4;
				PolygonDef.vertexCount = 4;
				PolygonDef.vertices[0].Set(-1.66, 0);
				PolygonDef.vertices[1].Set(1.66, 0);
				PolygonDef.vertices[2].Set(1.66, 0.33);
				PolygonDef.vertices[3].Set(-1.66, 0.33);
				PolygonDef.density = 50;
				PolygonDef.friction = 1;
				PolygonDef.restitution = 0;
				Body.CreateShape(PolygonDef);
				PolygonDef = new Box2D.Collision.Shapes.b2PolygonDef();
				PolygonDef.filter.categoryBits = 4;
				PolygonDef.vertexCount = 4;
				PolygonDef.vertices[0].Set(-1.33, 0);
				PolygonDef.vertices[1].Set(-0.33, -0.33);
				PolygonDef.vertices[2].Set(0.33, -0.33);
				PolygonDef.vertices[3].Set(1.33, 0);
				PolygonDef.density = 10;
				PolygonDef.friction = 0;
				PolygonDef.restitution = 1.5;
				Body.CreateShape(PolygonDef);
				Body.SetMassFromShapes();
			}
			this.ClipListeMobile.addChild(Objet);
			this.ListeMobile.push(Body);
			Objet.x = pX;
			Objet.y = pY;
			Objet.rotation = Rot;
			return Body;
		}

		public function Clique_Placement_Objet(ObjetCode:int):void {
			this.Annulation_Placement_Objet();
			this.ObjetEnCours = new (this.loaderInfo.applicationDomain.getDefinition("$Objet_" + ObjetCode) as Class)();
			this.ObjetEnCours.gotoAndStop(14);
			this.ObjetEnCours.mouseEnabled = false;
			this.ObjetEnCours.mouseChildren = false;
			stage.addEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Boucle_Placement);
			stage.addEventListener(flash.events.MouseEvent.MOUSE_WHEEL, this.Boucle_Molette);
			this.ClipMonde.addEventListener(flash.events.MouseEvent.MOUSE_DOWN, this.Validation_Placement_Objet);
			this.ObjetEnCours.x = this.ClipMonde.mouseX;
			this.ObjetEnCours.y = this.ClipMonde.mouseY + 3;
			this.ObjetEnCours.alpha = 0.5;
			this.ObjetEnCours.Code = ObjetCode;
			addChild(this.ObjetEnCours);
		}

		public function Validation_Placement_Objet(Event:flash.events.Event):void {
			var Object:MovieClip=this.ObjetEnCours;
			var Code:int=Object.Code;
			if (Code > 10 && Code < 17 || Code == 22) {
				this.Création_Clou(Code, this.ClipMonde.mouseX, this.ClipMonde.mouseY);
				this.Annulation_Placement_Objet();
				return;
			}
			if (this.Guide) {
				this.Creation_Objet(Code, int(Object.x), int(Object.y - 3), int(Object.rotation));
			}
			this.Envoie_Serveur(this.$5 + this.$20 + this.$1 + Code + this.$1 + int(Object.x) + this.$1 + int(Object.y - 3) + this.$1 + int(Object.rotation));
			if (this.AutoClou) {
				this.AutoClou = false;
				var ObjectClou:* = (this.ObjetEnCours.getChildAt((this.ObjetEnCours.numChildren - 1)) as flash.display.MovieClip).localToGlobal(new flash.geom.Point(0, 0));
				this.Création_Clou(this.AutoClouCode, ObjectClou.x, ObjectClou.y - 3);
			}
			this.Annulation_Placement_Objet();
		}

		public function Annulation_Placement_Objet():void {
			if (this.ObjetEnCours) {
				stage.removeEventListener(flash.events.MouseEvent.MOUSE_MOVE, this.Boucle_Placement);
				stage.removeEventListener(flash.events.MouseEvent.MOUSE_WHEEL, this.Boucle_Molette);
				this.ClipMonde.removeEventListener(flash.events.MouseEvent.MOUSE_DOWN, this.Validation_Placement_Objet);
				removeChild(this.ObjetEnCours);
				this.ObjetEnCours = null;
			}
		}
	}
}
