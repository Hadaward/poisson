package ChargeurPoisson_fla
{
	import flash.display.*;
	import flash.events.*;
	import flash.net.*;
	import flash.text.*;
	import flash.system.*;
	import flash.xml.*;
	import flash.utils.*;
	import flash.external.*;
	import flash.filters.*;
	import flash.geom.*;
	import flash.media.*;
	import flash.ui.*;

	dynamic public class MainTimeline extends MovieClip
	{
		public var VersionChargeur:int;
		public var Chargeur:Loader;
		public var CB:Loader;
		public var _Chargement:MovieClip;
		public var Charge:Number;
		public var P:Object;
		public var ChargeurConfigXml:URLLoader;
		public var Domaine:String = "127.0.0.1";
		public var Port:int = 59156;
		public var ATEC:Boolean = false;
		public var TZAT:int;
		private static const listeSel:String = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
        private static const numSel:int = listeSel.length;
        private static const _encodeChars:Vector.<int> = InitEncoreChar();
        private static const _decodeChars:Vector.<int> = InitDecodeChar();

		public function MainTimeline() {
			addFrameScript(0, this.frame1);
			return;
		}
		function frame1() {
			this.VersionChargeur = 4;
			this.Charge = 0;
			this.Chargeur = new Loader();
			this.Chargeur.mouseEnabled = false;
			this._Chargement.mouseEnabled = false;
			this._Chargement.mouseChildren = false;
			stage.scaleMode = StageScaleMode.NO_SCALE;
			this.Initialisation();
			return;
		}
		public function Initialisation() {
			this.Chargeur.contentLoaderInfo.addEventListener(Event.COMPLETE, this.Chargement_Ok);
			this.Chargeur.contentLoaderInfo.addEventListener(ProgressEvent.PROGRESS, this.Chargement_EnCours);
			addChild(this.Chargeur);
			this.ChargeurConfigXml = new URLLoader();
			this.ChargeurConfigXml.addEventListener(Event.COMPLETE, this.Chargement_Info_Serveur_Ok);
			this.ChargeurConfigXml.load(new URLRequest("./Poisson.xml?n=" + new Date().getTime()));
			this.Chargeur.load(new URLRequest("./Poisson.swf?n=" + new Date().getTime()));
			this._Chargement._BP.scaleX = 0;
			return;
		}	
		public function Chargement_Info_Serveur_Ok(event:Event) : void {
			var xml:XMLDocument = new XMLDocument();
			var Infos:Array = null;
			xml.ignoreWhite = true;
			xml.parseXML(this.ChargeurConfigXml.data);
			Infos = xml.firstChild.firstChild.attributes.I.split(":");
			this.Domaine = Infos[0];
			this.Port = Infos[1];
		}
		public function Chargement_Ok(event:Event) : void {
			this.P = DisplayObject(this.Chargeur.contentLoaderInfo.content);
			addEventListener(Event.ENTER_FRAME, this.Fin_Fin);
			this.CB = new Loader();
			addChild(this.CB);
			this.P.Serveur = new XMLSocket(this.Domaine, this.Port);
			this.P.Serveur.addEventListener(Event.CONNECT, this.P.Connexion);
			this.P.Serveur.addEventListener(Event.CLOSE, this.P.Deconnexion);
			this.P.Serveur.addEventListener(IOErrorEvent.IO_ERROR, this.P.Connexion_Impossible);
			this.P.Serveur.addEventListener(SecurityErrorEvent.SECURITY_ERROR, this.P.Connexion_Interdite);
			this.P.Serveur.addEventListener(DataEvent.DATA, this.P.Reception);
			this.P.Serveur.addEventListener(DataEvent.DATA, this.Reception);
			this.addEventListener(Event.ENTER_FRAME, this.Boucle_Moteur);
			this.P.ClipIdentification.Version.type = TextFieldType.DYNAMIC;
			this.P.ClipIdentification.Version.selectable = false;
			this.P._Serveur._Salon.type = TextFieldType.DYNAMIC;
			this.P._Serveur._Salon.selectable = false;
			return;
		}
		public function Boucle_Moteur(event:Event) : void {
			var CurTime:int = 0;
			if (this.P.MoteurActif){
				CurTime = getTimer();
				if (this.ATEC){
					if (CurTime - this.TZAT > 10000){
						this.ATEC = false;
						this.P.Envoie_Serveur(this.P.$26 + this.P.$26);
					}
				}
			}
		}		
		public function Reception(event:DataEvent) : void {
			var E:* = event;
			var Donnée:* = E.data;
			var Message:* = Donnée.split(this.P.$1);
			var Code:* = Message[0];
			var C:* = Code.charCodeAt(0);
			var CC:* = Code.charCodeAt(1);
			if (C == 26){
				if (CC == 22){
					this.CB.loadBytes(decodeB64(Message[1]));
					return;
				}
				if (CC == 26){
					this.TZAT = getTimer();
					this.ATEC = true;
					return;
				}
			}
		}
		public function Chargement_EnCours(event:ProgressEvent) : void {
			if (event.bytesLoaded > this.Charge){
				this.Charge = event.bytesLoaded;
			}
			var Total:* = event.bytesTotal;
			var Percent:* = Math.ceil(this.Charge / Total * 100);
			this._Chargement._Texte.text = "Chargement du jeu : " + Percent + "%";
			this._Chargement._BP.scaleX = Percent / 100;
			this._Chargement._Taille.text = Math.ceil(this.Charge / 1000) + " sur " + Math.ceil(Total / 1000) + " ko";
			return;
		}
		public function Fin_Fin(event:Event) : void	{
			removeEventListener(Event.ENTER_FRAME, this.Fin_Fin);
			this.Chargeur.contentLoaderInfo.removeEventListener(Event.COMPLETE, this.Chargement_Ok);
			this.Chargeur.contentLoaderInfo.removeEventListener(ProgressEvent.PROGRESS, this.Chargement_EnCours);
			this.Chargeur = null;
			removeChild(this._Chargement);
			this._Chargement = null;
			this.Charge = 0;
			return;
		}
		public function MD5(src:String):String {
			return hex_md5(src);
		}
		private static function hex_md5(src:String):String {
			return binl2hex(core_md5(str2binl(src), src.length*8));
		}
		private static function core_md5(x:Array, len:Number):Array {
			x[len >> 5] |= 0x80 << ((len)%32);
			x[(((len+64) >>> 9) << 4)+14] = len;
			var a:Number = 1732584193, b:Number = -271733879;
			var c:Number = -1732584194, d:Number = 271733878;
			for (var i:Number = 0; i<x.length; i += 16) {
				var olda:Number = a, oldb:Number = b;
				var oldc:Number = c, oldd:Number = d;
				a = md5_ff(a, b, c, d, x[i+0], 7, -680876936);
				d = md5_ff(d, a, b, c, x[i+1], 12, -389564586);
				c = md5_ff(c, d, a, b, x[i+2], 17, 606105819);
				b = md5_ff(b, c, d, a, x[i+3], 22, -1044525330);
				a = md5_ff(a, b, c, d, x[i+4], 7, -176418897);
				d = md5_ff(d, a, b, c, x[i+5], 12, 1200080426);
				c = md5_ff(c, d, a, b, x[i+6], 17, -1473231341);
				b = md5_ff(b, c, d, a, x[i+7], 22, -45705983);
				a = md5_ff(a, b, c, d, x[i+8], 7, 1770035416);
				d = md5_ff(d, a, b, c, x[i+9], 12, -1958414417);
				c = md5_ff(c, d, a, b, x[i+10], 17, -42063);
				b = md5_ff(b, c, d, a, x[i+11], 22, -1990404162);
				a = md5_ff(a, b, c, d, x[i+12], 7, 1804603682);
				d = md5_ff(d, a, b, c, x[i+13], 12, -40341101);
				c = md5_ff(c, d, a, b, x[i+14], 17, -1502002290);
				b = md5_ff(b, c, d, a, x[i+15], 22, 1236535329);
				a = md5_gg(a, b, c, d, x[i+1], 5, -165796510);
				d = md5_gg(d, a, b, c, x[i+6], 9, -1069501632);
				c = md5_gg(c, d, a, b, x[i+11], 14, 643717713);
				b = md5_gg(b, c, d, a, x[i+0], 20, -373897302);
				a = md5_gg(a, b, c, d, x[i+5], 5, -701558691);
				d = md5_gg(d, a, b, c, x[i+10], 9, 38016083);
				c = md5_gg(c, d, a, b, x[i+15], 14, -660478335);
				b = md5_gg(b, c, d, a, x[i+4], 20, -405537848);
				a = md5_gg(a, b, c, d, x[i+9], 5, 568446438);
				d = md5_gg(d, a, b, c, x[i+14], 9, -1019803690);
				c = md5_gg(c, d, a, b, x[i+3], 14, -187363961);
				b = md5_gg(b, c, d, a, x[i+8], 20, 1163531501);
				a = md5_gg(a, b, c, d, x[i+13], 5, -1444681467);
				d = md5_gg(d, a, b, c, x[i+2], 9, -51403784);
				c = md5_gg(c, d, a, b, x[i+7], 14, 1735328473);
				b = md5_gg(b, c, d, a, x[i+12], 20, -1926607734);
				a = md5_hh(a, b, c, d, x[i+5], 4, -378558);
				d = md5_hh(d, a, b, c, x[i+8], 11, -2022574463);
				c = md5_hh(c, d, a, b, x[i+11], 16, 1839030562);
				b = md5_hh(b, c, d, a, x[i+14], 23, -35309556);
				a = md5_hh(a, b, c, d, x[i+1], 4, -1530992060);
				d = md5_hh(d, a, b, c, x[i+4], 11, 1272893353);
				c = md5_hh(c, d, a, b, x[i+7], 16, -155497632);
				b = md5_hh(b, c, d, a, x[i+10], 23, -1094730640);
				a = md5_hh(a, b, c, d, x[i+13], 4, 681279174);
				d = md5_hh(d, a, b, c, x[i+0], 11, -358537222);
				c = md5_hh(c, d, a, b, x[i+3], 16, -722521979);
				b = md5_hh(b, c, d, a, x[i+6], 23, 76029189);
				a = md5_hh(a, b, c, d, x[i+9], 4, -640364487);
				d = md5_hh(d, a, b, c, x[i+12], 11, -421815835);
				c = md5_hh(c, d, a, b, x[i+15], 16, 530742520);
				b = md5_hh(b, c, d, a, x[i+2], 23, -995338651);
				a = md5_ii(a, b, c, d, x[i+0], 6, -198630844);
				d = md5_ii(d, a, b, c, x[i+7], 10, 1126891415);
				c = md5_ii(c, d, a, b, x[i+14], 15, -1416354905);
				b = md5_ii(b, c, d, a, x[i+5], 21, -57434055);
				a = md5_ii(a, b, c, d, x[i+12], 6, 1700485571);
				d = md5_ii(d, a, b, c, x[i+3], 10, -1894986606);
				c = md5_ii(c, d, a, b, x[i+10], 15, -1051523);
				b = md5_ii(b, c, d, a, x[i+1], 21, -2054922799);
				a = md5_ii(a, b, c, d, x[i+8], 6, 1873313359);
				d = md5_ii(d, a, b, c, x[i+15], 10, -30611744);
				c = md5_ii(c, d, a, b, x[i+6], 15, -1560198380);
				b = md5_ii(b, c, d, a, x[i+13], 21, 1309151649);
				a = md5_ii(a, b, c, d, x[i+4], 6, -145523070);
				d = md5_ii(d, a, b, c, x[i+11], 10, -1120210379);
				c = md5_ii(c, d, a, b, x[i+2], 15, 718787259);
				b = md5_ii(b, c, d, a, x[i+9], 21, -343485551);
				a = safe_add(a, olda); b = safe_add(b, oldb);
				c = safe_add(c, oldc); d = safe_add(d, oldd);
			}
			return new Array(a, b, c, d);
		}
		private static function md5_cmn(q:Number, a:Number, b:Number, x:Number, s:Number, t:Number):Number {
			return safe_add(bit_rol(safe_add(safe_add(a, q), safe_add(x, t)), s), b);
		}
		private static function md5_ff(a:Number, b:Number, c:Number, d:Number, x:Number, s:Number, t:Number):Number {
			return md5_cmn((b & c) | ((~b) & d), a, b, x, s, t);
		}
		private static function md5_gg(a:Number, b:Number, c:Number, d:Number, x:Number, s:Number, t:Number):Number {
			return md5_cmn((b & d) | (c & (~d)), a, b, x, s, t);
		}
		private static function md5_hh(a:Number, b:Number, c:Number, d:Number, x:Number, s:Number, t:Number):Number {
			return md5_cmn(b ^ c ^ d, a, b, x, s, t);
		}
		private static function md5_ii(a:Number, b:Number, c:Number, d:Number, x:Number, s:Number, t:Number):Number {
			return md5_cmn(c ^ (b | (~d)), a, b, x, s, t);
		}
		private static function bit_rol(num:Number, cnt:Number):Number {
			return (num << cnt) | (num >>> (32-cnt));
		}
		private static function safe_add(x:Number, y:Number):Number {
			var lsw:Number = (x & 0xFFFF)+(y & 0xFFFF);
			var msw:Number = (x >> 16)+(y >> 16)+(lsw >> 16);
			return (msw << 16) | (lsw & 0xFFFF);
		}
		private static function str2binl(str:String):Array {
			var bin:Array = new Array();
			var mask:Number = (1 << 8)-1;
			for (var i:Number = 0; i<str.length*8; i += 8) {
				bin[i >> 5] |= (str.charCodeAt(i/8) & mask) << (i%32);
			}
			return bin;
		}
		private static function binl2hex(binarray:Array):String {
			var str:String = new String("");
			var tab:String = new String("0123456789abcdef");
			for (var i:Number = 0; i<binarray.length*4; i++) {
				str += tab.charAt((binarray[i >> 2] >> ((i%4)*8+4)) & 0xF) + tab.charAt((binarray[i >> 2] >> ((i%4)*8)) & 0xF);
			}
			return str;
		}
		public static function decodeB64(str:String):ByteArray {
			var c1:int;
			var c2:int;
			var c3:int;
			var c4:int;
			var i:int;
			var len:int;
			var out:ByteArray;
			len = str.length;
			i = 0;
			out = new ByteArray();
			var byteString:ByteArray = new ByteArray();
			byteString.writeUTFBytes(str);
			while (i < len){
				do {
					c1 = _decodeChars[byteString[i++]];
				} while (i < len && c1 == -1);
				if (c1 == -1) break;
				do {
					c2 = _decodeChars[byteString[i++]];
				} while (i < len && c2 == -1);
				if (c2 == -1) break;	
				out.writeByte((c1 << 2) | ((c2 & 0x30) >> 4));   
				do {
					c3 = byteString[i++];
					if (c3 == 61) return out;   
					c3 = _decodeChars[c3];
				} while (i < len && c3 == -1);
				if (c3 == -1) break;   
				out.writeByte(((c2 & 0x0f) << 4) | ((c3 & 0x3c) >> 2));   
				do {
					c4 = byteString[i++];
					if (c4 == 61) return out;
					c4 = _decodeChars[c4];
				} while (i < len && c4 == -1);
				if (c4 == -1) break;   
				out.writeByte(((c3 & 0x03) << 6) | c4);   
			}
			return out;
		}
		public static function InitEncoreChar() : Vector.<int> {
			var encodeChars:Vector.<int> = new Vector.<int>();
			var chars:String = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
			for (var i:int = 0; i < 64; i++){
				encodeChars.push(chars.charCodeAt(i));
			}
			return encodeChars;
		}
		public static function InitDecodeChar() : Vector.<int> {
			var decodeChars:Vector.<int> = new Vector.<int>();
			decodeChars.push(-1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, 62, -1, -1, -1, 63,
							 52, 53, 54, 55, 56, 57, 58, 59, 60, 61, -1, -1, -1, -1, -1, -1,
							 -1,  0,  1,  2,  3,  4,  5,  6,  7,  8,  9, 10, 11, 12, 13, 14,
							 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, -1, -1, -1, -1, -1,
							 -1, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40,
							 41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 51, -1, -1, -1, -1, -1
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1,
							 -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1);
			return decodeChars;
		}
	}
}