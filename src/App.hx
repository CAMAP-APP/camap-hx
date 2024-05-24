import Common;
import GitMacros;
import db.User;
import thx.semver.Version;

class App extends sugoi.BaseApp {

	public static var current : App = null;
	public static var t : sugoi.i18n.translator.ITranslator;
	public static var config = sugoi.BaseApp.config;
	public static var eventDispatcher : hxevents.Dispatcher<Event>;	
	public static var plugins : Array<sugoi.plugin.IPlugIn>;
	

	public var breadcrumb : Array<Link>;
	public static var theme	: Theme;

	/**
	 * Version management
	 * @doc https://github.com/fponticelli/thx.semver
	 */ 
	public static var VERSION = ([1,1,1]  : Version)/*.withPre(GitMacros.getGitShortSHA(), GitMacros.getGitCommitDate())*/;
	
	public function new(){
		super();

		breadcrumb = [];

		if (App.config.DEBUG) {
			this.headers.set('Access-Control-Allow-Origin', "*");
			this.headers.set("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
		}
	}
	
	public static function main() {
		
		App.t = sugoi.form.Form.translator = new sugoi.i18n.translator.TMap(getTranslationArray(), "fr");
		sugoi.BaseApp.main();
	}
	
	/**
	 * Init plugins and event dispatcher just before launching the app
	 */
	override public function mainLoop() {
		super.mainLoop();
	}

	override function init(){
		var i = super.init();

		if(eventDispatcher==null){
			eventDispatcher = new hxevents.Dispatcher<Event>();
			plugins = [];
			
			setTheme();
		}

		return i;

	}

 public function setTheme(){
        var defaultTheme: Theme = {
            id: "default",
            name: "CAMAP",
            supportEmail: "inter@amap44.org",
            footer: {
                bloc1: '<a href="http://camap.amap44.org" target="_blank">
                            <img src="/theme/default/logo.png" alt="CAMAP" style="width:105px;"/>
                        </a>',
                bloc2: '<ul>
                            <li>
                                <a href="https://wiki.amap44.org" target="_blank">Documentation</a>
                            </li>
                            <li>
                                <a href="https://www.facebook.com/groups/camap44/" target="_blank">Groupe d\'Entraide Facebook</a>
                            </li>
                            <li>
                                <a href="/cgu" target="_blank">Conditions générales d\'utilisation</a>
                            </li>
                            <li>
                            <a href="https://feedback.amap44.org" target="_blank">Idées & Suggestions</a>
                            </li>
                            <li>
                            <a href="https://mantisbt.amap44.org" target="_blank">Signaler un bug</a>
                            </li>
                        </ul>',
                bloc3: 'CAMAP est hébergé <br>
                        par <b>l\'InterAMAP44</b><br/></a>et développé sous licence GPLv3<br>
                        <ul>
                            <li>
                               Contacter le Support: <u>support@amap44.org</u>
                            </li>
                         </ul>
                        ',
                bloc4: '
							<a href=\"http://www.amap44.org\" target=\"_blank\">
								<img src=\"/theme/default/logo_amap44.png\" alt=\"CAMAP\" style=\"width:145px;\"/>
							</a>
							<br>
							<table>
								<caption style=\"color:white\">Camap est co-financé par:</caption>
								<tr>
									<td>
										<img src=\"/theme/default/Logo_NM.png\" alt=\"Logo Nantes Métropole\" style=\"width:60px;\"/>&nbsp;
									</td>
									<td>
										<img src=\"/theme/default/Logo_BUPA.png\" alt=\"Logo Budget Participatif de Loire-Atlantique 2023\" style=\"width:60px;\"/>&nbsp;
									</td>
									<td>
										<img src=\"/theme/default/Logo_PDL.png\" alt=\"Logo Pays-de-la-Loire\" style=\"width:60px;\"/>
									</td>
								</tr>
							</table>
                       '
            },
            email:{
                senderEmail : 'noreply@camap.amap44.org',
                brandedEmailLayoutFooter:  '<p>InterAMAP44, 1 Boulevard Boulay-Paty – 44100 Nantes</p>
                <div style="display: flex; justify-content: center; align-items: center;">
                    <a href="https://www.amap44.org" target="_blank" rel="noreferrer noopener notrack" class="bold-green" style="text-decoration:none !important; padding: 8px; display: flex; align-items: center;">
                        <img src="http://'+ App.config.HOST+'/img/emails/website.png" alt="Site web" height="25" style="width:auto!important; height:25px!important; vertical-align:middle" valign="middle" width="auto"/>Site web
                    </a>
                    <a href="https://www.facebook.com/groups/camap44" target="_blank" rel="noreferrer noopener notrack" class="bold-green" style="text-decoration:none !important; padding: 8px; display: flex; align-items: center;">
                        <img src="http://'+ App.config.HOST+'/img/emails/facebook.png" alt="Facebook" height="25" style="width:auto!important; height:25px!important; vertical-align:middle" valign="middle" width="auto"/>Facebook
                    </a>
                </div>'
            },
            terms: {
                termsOfServiceLink: "https://www.amap44.org/CGU/",
                termsOfSaleLink: "https://www.amap44.org/CGU/",
                platformTermsOfServiceLink: "https://www.amap44.org/CGU/",
                privacyPolicyLink: "https://www.amap44.org/CGU/",
            }

        }
        try {
            var res = this.cnx.request("SELECT value FROM Variable WHERE name='whiteLabel'").results();
            var whiteLabelStringified = res.first() == null ? null : res.first().value;
            App.theme = whiteLabelStringified != null ? haxe.Json.parse(whiteLabelStringified) : defaultTheme;
        } catch (e : Dynamic) {
            App.theme = defaultTheme;
        }
    }

	/**
		Theme is stored as static var, thus it's inited only one time at app startup
	**/
	public function getTheme():Theme{
		return App.theme;
	}

	public function getCurrentGroup(){		
		if (session == null) return null;
		if (session.data == null ) return null;
		var a = session.data.amapId;
		if (a == null) {
			return null;
		}else {			
			return db.Group.manager.get(a,false);
		}
	}
	
	override function beforeDispatch() {
		
		//send "current page" event
		event( Page(this.uri) );
		
		super.beforeDispatch();
	}
	
	public function getPlugin(name:String):sugoi.plugin.IPlugIn {
		for (p in plugins) {
			if (p.getName() == name) return p;
		}
		return null;
	}
	
	public static function log(t:Dynamic) {
		if(App.config.DEBUG) {
			neko.Web.logMessage(Std.string(t)); //write in Apache error log
			#if weblog
			Weblog.log(t); //write en Weblog console (https://lib.haxe.org/p/weblog/)
			#end
		}
	}
	
	public function event(e:Event) {
		if(e==null) return null;
		App.eventDispatcher.dispatch(e);
		return e;
	}
	
	/**
	 * Translate DB objects fields in forms
	 */
	public static function getTranslationArray() {
		//var t = sugoi.i18n.Locale.texts;
		var out = new Map<String,String>();

		out.set("firstName2", "Prénom du conjoint");
		out.set("lastName2", "Nom du conjoint");
		out.set("email2", "e-mail du conjoint");
		out.set("zipCode", "code postal");
		out.set("city", "commune");
		out.set("phone", "téléphone");
		out.set("phone2", "téléphone du conjoint");


		out.set("select", "sélectionnez");
		out.set("contract", "Contrat");
		out.set("place", "Lieu");
		out.set("name", "Nom");
		out.set("cdate", "Date d'entrée dans le groupe");
		out.set("quantity", "Quantité");
		out.set("paid", "Payé");
		out.set("user2", "(facultatif) partagé avec ");
		out.set("product", "Produit");
		out.set("user", "Adhérent");
		out.set("txtIntro", "Texte de présentation du groupe");
		out.set("txtHome", "Texte en page d'accueil pour les adhérents connectés");
		out.set("txtDistrib", "Texte à faire figurer sur les listes d'émargement lors des distributions");
		out.set("extUrl", "URL du site du groupe.");
		
		out.set("startDate", "Date de début");
		out.set("endDate", "Date de fin");
		
		out.set("orderStartDate", "Date ouverture des commandes");
		out.set("orderEndDate", "Date fermeture des commandes");	
		out.set("openingHour", "Heure d'ouverture");	
		out.set("closingHour", "Heure de fermeture");	
		
		out.set("date", "Date de distribution");	
		out.set("active", "actif");	
		
		out.set("contact", "Reponsable");
		out.set("vendor", "Producteur");
		out.set("text", "Texte");
	
		out.set("flags", "Options");
		out.set("HasEmailNotif4h", "Recevoir des notifications par email 4h avant les distributions");
		out.set("HasEmailNotif24h", "Recevoir des notifications par email 24h avant les distributions");
		out.set("HasEmailNotifOuverture", "Recevoir des notifications par email pour l'ouverture des commandes");

		out.set("HasMembership", "Gestion des adhésions");
		out.set("DayOfWeek", "Jour de la semaine");
		out.set("Monday", "Lundi");
		out.set("Tuesday", "Mardi");
		out.set("Wednesday", "Mercredi");
		out.set("Thursday", "Jeudi");
		out.set("Friday", "Vendredi");
		out.set("Saturday", "Samedi");
		out.set("Sunday", "Dimanche");
		out.set("cycleType", "Récurrence");
		out.set("Weekly", "hebdomadaire");
		out.set("Monthly", "mensuelle");
		out.set("BiWeekly", "toutes les deux semaines");
		out.set("TriWeekly", "toutes les 3 semaines");
		out.set("price", "prix TTC");
		out.set("uname", "Nom");
		out.set("pname", "Produit");
		out.set("organic", "Agriculture biologique");
		
		out.set("membershipRenewalDate", "Adhésions : Date de renouvellement");
		out.set("membershipPrice", "Adhésions : Coût de l'adhésion");
		out.set("UsersCanOrder", "Les membres peuvent saisir leur commande en ligne");
		out.set("StockManagement", "Gestion des stocks");
		out.set("DisplayPricesOnGroupPage", "Afficher les prix des produits sur la page publique du groupe");
		out.set("contact", "Responsable");
		out.set("PercentageOnOrders", "Ajouter des frais au pourcentage de la commande");
		out.set("percentageValue", "Pourcentage des frais");
		out.set("percentageName", "Libellé pour ces frais");
		out.set("fees", "frais");
		out.set("AmapAdmin", "Administrateur du groupe");
		out.set("Membership", "Accès à la gestion des membres");
		out.set("Messages", "Accès à la messagerie");
		out.set("vat", "TVA");
		out.set("desc", "Description");
		
		//group options
		out.set("HidePhone", "Masquer le téléphone du responsable sur la page publique");
		out.set("PhoneRequired", "Saisie du numéro de téléphone obligatoire");
		out.set("AddressRequired", "Saisie de l'adresse obligatoire");

		out.set("ref", "Référence");
		out.set("linkText", "Intitulé du lien");
		out.set("linkUrl", "URL du lien");
		
		out.set("regOption", 	"Inscription de nouveaux membres");
		out.set("Closed", 		"Fermé : L'administrateur ajoute les nouveaux membres");
		out.set("WaitingList", 	"Liste d'attente");
		out.set("Open", 		"Ouvert : tout le monde peut s'inscrire");
		out.set("Full", 		"Complet : Le groupe n'accepte plus de nouveaux membres");

		out.set("Soletrader"	, "Micro-entreprise");
		out.set("Organization"	, "Association");
		out.set("Business"		, "Société");		
		
		out.set("unitType", "Unité");
		out.set("qt", "Quantité");
		out.set("Unit", "Pièce");
		out.set("Kilogram", "Kilogrammes");
		out.set("Gram", "Grammes");
		out.set("Litre", "Litres");		
		out.set("Centilitre", "Centilitres");		
		out.set("Millilitre", "Millilitres");		
		out.set("htPrice", "Prix H.T");
		out.set("amount", "Montant");
		out.set("percent", "Pourcentage");
		out.set("pinned", "Mets en avant les produits");
		
		out.set("byMember", "Par adhérent");
		out.set("byProduct", "Par produit");

		//stock strategy
		out.set("ByProduct"	, "Par produit (produits vrac, stockés sans conditionnement)");
		out.set("ByOffer"	, "Par offre (produits stockés déja conditionnés)");
				
		out.set("variablePrice", "Prix variable selon pesée");	
		out.set("VATAmount", "Montant TVA");	
		out.set("VATRate", "Taux TVA");
	
		return out;
	}
	
	public function populateAmapMembers() {		
		return user.getGroup().getMembersFormElementData();
	}
	
	public static function getMailer():sugoi.mail.IMailer {
		var mailer : sugoi.mail.IMailer = new mail.BufferedJsonMailer();		
		return mailer;
	}
	
	/**
	 * Send an email
	 */
	public static function sendMail(m:sugoi.mail.Mail, ?group:db.Group, ?sender:{email: String, ?name: String,?userId: Int}){
		
		if (group == null) group = App.current.user == null ? null:App.current.user.getGroup();
		if (group != null) m.setSender(group.contact == null ? App.current.getTheme().email.senderEmail : group.contact.email, group.name);
		if (sender != null) m.setSender(sender.email, sender.name, sender.userId);
		current.event(SendEmail(m));
		var params = group==null ? null : {remoteId:group.id};
		getMailer().send(m,params,function(o){});		
	}
	
	public static function quickMail(to:String, subject:String, html:String,?group:db.Group){
		var e = new sugoi.mail.Mail();		
		e.setSubject(subject);
		e.setRecipient(to);			
		e.setSender(App.current.getTheme().email.senderEmail, App.current.getTheme().name);				
		var html = App.current.processTemplate("mail/message.mtt", {text:html,group:group});		
		e.setHtmlBody(html);
		App.sendMail(e, group);
	}
	
	/**
		process a template and returns the generated string
		(used for emails)
	**/
	public function processTemplate(tpl:String, ctx:Dynamic):String {
		
		//inject usefull vars in view
		Reflect.setField(ctx, 'HOST', App.config.HOST);
		Reflect.setField(ctx, 'theme', this.getTheme());
		Reflect.setField(ctx, 'hDate', date -> return Formatting.hDate(date) );

		ctx._ = App.current.view._;
		ctx.__ = App.current.view.__;
		
		var tpl = loadTemplate(tpl);
		var html = tpl.execute(ctx);	
		#if php
		if ( html.substr(0, 4) == "null") html = html.substr(4);
		#end
		return html;
	}
	
	
	
}
