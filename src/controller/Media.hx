package controller;

import sugoi.form.elements.StringInput;
import sugoi.form.elements.RadioGroup;

class Media extends controller.Controller
{
	public function new()
	{
		super();		
	}

	
	//  View the media for a group
	@tpl("contractadmin/media.mtt")
	function doDefault() {

		if ( !app.user.isAmapManager() ) throw Error( '/', t._('Access forbidden') );
		var media : Array<sugoi.db.EntityFile> = sugoi.db.EntityFile.getByEntity( 'group', app.user.getGroup().id, 'media' );

		view.nav.push( 'media' );
		view.media = media;

		//generate a token
		checkToken();
	}
	
	@tpl("form.mtt")
	public function doEdit( media : sugoi.db.EntityFile ) {

		var returnPath : String = null;
		if ( !app.user.isAmapManager() ) throw Error( '/', t._('Access forbidden') );
		returnPath = '/amapadmin/media';
		
		var form = new sugoi.form.Form("mediaEdit");
		view.title = "Editer le media ici";
		view.text = "Vous pouvez changer le nom et la visibilité du media ici.<br/>";
		
		form.addElement( new StringInput( "name","Nom du media", media.file.name, true ) );

		var options = [ { value : "public", label : "Public" } ];

		form.addElement( new RadioGroup( 'visibility', 'Visibilité', options, media.data != null ? media.data : 'members' ) );
	
		if( form.isValid() ) {
			
			media.lock();
			media.file.lock();
			media.file.name = form.getValueOf("name");
			media.data = form.getValueOf("visibility");
			media.file.update();
			media.update();
				
			throw Ok( returnPath, 'Le media ' + media.file.name + ' a bien été mis à jour.' );
		}
			
		view.form = form;
	}


	public function doDelete( media : sugoi.db.EntityFile) {

		if ( !app.user.isAmapManager() ) throw Error( '/', t._('Access forbidden') );
		var returnPath : String = '/amapadmin/media';

		if ( checkToken() ) {

			media.lock();
			media.file.lock();
			var name = media.file.name;
			media.delete();
			media.file.delete();

			throw Ok( returnPath, 'Le media ' + name + ' a bien été supprimé.' );
			
		}

		throw Error( returnPath, t._("Token error") );
	}


	@tpl("contractadmin/addmedia.mtt")
	public function doInsert() {

		if ( !app.user.isAmapManager() ) throw Error( '/', t._('Access forbidden') );
		var existingMedia = sugoi.db.EntityFile.manager.count( $entityType == 'group' && $entityId == app.user.getGroup().id && $documentType == 'media' );
		if (existingMedia >= 5) {
			throw Error( '/amapadmin/media', t._('Media limit reached') );
		}
		var returnPath : String = '/amapadmin/media';
		var errorPath : String = '/amapadmin/media/insert';

		view.nav.push( 'media' );

		var request = new Map();
		try {
			request = sugoi.tools.Utils.getMultipart( 1024 * 1024 * 4 ); //3Mb
		} catch ( e:Dynamic ) {
			throw Error( errorPath, 'Le media importé est trop volumineux. Il ne doit pas dépasser 3 Mo.');
		}
		
		if ( request.exists( 'media' ) ) {
			
			var doc = request.get( 'media' );
			if ( doc != null && doc.length > 0 ) {

				var originalFilename = request.get( 'media_filename' );
				if ( !StringTools.endsWith( originalFilename.toLowerCase(), '.jpg' )
					&& !StringTools.endsWith( originalFilename.toLowerCase(), '.jpeg' ) 
					&& !StringTools.endsWith( originalFilename.toLowerCase(), '.png' ) 
					&& !StringTools.endsWith( originalFilename.toLowerCase(), '.bmp' ) 
					&& !StringTools.endsWith( originalFilename.toLowerCase(), '.gif' ) 
				) {
					throw Error( errorPath, 'Le media n\'est pas au format jpg, bmp, gif ou png. Veuillez sélectionner un fichier au format jpg, bmp, gif ou png.');
				}
				
				var filename = ( request.get( 'name' ) == null || request.get( 'name' ) == '' ) ? originalFilename : request.get( 'name' );
				var file : sugoi.db.File = sugoi.db.File.create( request.get( 'media' ), filename );
				var media = new sugoi.db.EntityFile();
				media.entityType = 'group';
				media.entityId = app.user.getGroup().id;
				media.documentType = 'media';
				media.file = file;
				media.data = request.get( 'visibility' );
				media.insert();
	
				throw Ok( returnPath, 'Le media ' + media.file.name + ' a bien été ajouté.' );
			}
		}
				
	}

}
