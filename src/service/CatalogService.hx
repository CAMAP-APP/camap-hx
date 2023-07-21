package service;
import sugoi.form.elements.IntInput;
import tools.DateTool;
import db.Catalog;
import tink.core.Error;

class CatalogService{


    public static function getForm( catalog:db.Catalog ) : sugoi.form.Form {

		if ( catalog.group == null || catalog.type == null || catalog.vendor == null ) {
			throw new tink.core.Error( "Un des éléments suivants est manquant : le groupe, le type, ou le producteur." );
		}

		var t = sugoi.i18n.Locale.texts;

		var customMap = new form.CamapForm.FieldTypeToElementMap();
		customMap["DDate"] = form.CamapForm.renderDDate;
		customMap["DTimeStamp"] = form.CamapForm.renderDDate;
		customMap["DDateTime"] = form.CamapForm.renderDDate;

		var form = form.CamapForm.fromSpod( catalog, customMap );
		
		form.removeElement(form.getElement("groupId") );
		form.removeElement(form.getElement("type"));
		form.removeElement(form.getElement("vendorId"));

		//not in this form
		form.removeElement(form.getElement("absentDistribsMaxNb"));
		form.removeElement(form.getElement("absencesStartDate"));
		form.removeElement(form.getElement("absencesEndDate"));
		
		
		form.removeElementByName("percentageValue");
		form.removeElementByName("percentageName");
		untyped form.getElement("flags").excluded = [2];// remove unused "PercentageOnOrders" flag

		var absencesIndex = 16;
		if ( catalog.type == Catalog.TYPE_VARORDER ) {
			//VAR
			form.addElement( new sugoi.form.elements.Html( 'constraints', '<h4>Engagement</h4>', '' ), 10 );
			form.addElement( new sugoi.form.elements.Html( 'constraintsHtml', 'Définissez ici l\'engagement minimum pour ce contrat. <br/><a href="https://wiki.amap44.org/fr/app/Administration-CAMAP#engagements" target="_blank"><i class="icon icon-info"></i> Pour plus d\'informations, consultez la documentation</a>.', '' ), 11 );

			form.getElement("orderStartDaysBeforeDistrib").docLink = "https://wiki.amap44.org/fr/app/admin-contrat-variable#ouverture-et-fermeture-de-commande";
			form.getElement("orderEndHoursBeforeDistrib").docLink = "https://wiki.amap44.org/fr/app/admin-contrat-variable#ouverture-et-fermeture-de-commande";				
			// form.getElement("catalogMinOrdersTotal").docLink = "";
			
		} else { 
			//CONST
			form.removeElement(form.getElement("orderStartDaysBeforeDistrib"));
			form.removeElement(form.getElement("requiresOrdering"));
			form.removeElement(form.getElement("distribMinOrdersTotal"));
			form.removeElement(form.getElement("catalogMinOrdersTotal"));

			form.getElement("orderEndHoursBeforeDistrib").label = "Délai minimum pour saisir une souscription (nbre d'heures avant prochaine distribution)";
			form.getElement("orderEndHoursBeforeDistrib").docLink = "https://wiki.amap44.org/fr/app/admin-contrat-classique#champs-d%C3%A9lai-minimum-pour-saisir-une-souscription";

			absencesIndex = 9;
		}
		
		
		if ( catalog.id == null ) {
			//if catalog is new
			if ( catalog.type == Catalog.TYPE_VARORDER ) {
				form.getElement("orderStartDaysBeforeDistrib").value = 365;					
			}
			form.getElement("orderEndHoursBeforeDistrib").value = 24;
		} 

			//For all types and modes
		if ( catalog.id != null ) {
			form.removeElement(form.getElement("distributorNum"));
		} else {

			form.getElement("name").value = "Contrat AMAP " + ( catalog.type == Catalog.TYPE_VARORDER ? "variable" : "classique" ) + " - " + catalog.vendor.name;
			form.getElement("startDate").value = Date.now();
			form.getElement("endDate").value = DateTools.delta( Date.now(), 365.25 * 24 * 60 * 60 * 1000 );
		}

		form.getElement("startDate").docLink = "https://wiki.amap44.org/fr/app/admin-contrat-classique#dates-de-d%C3%A9but-et-dates-de-fins";
		form.getElement("endDate").docLink = "https://wiki.amap44.org/fr/app/admin-contrat-classique#dates-de-d%C3%A9but-et-dates-de-fins";
		
		form.addElement( new sugoi.form.elements.Html( "vendorHtml", '<b>${catalog.vendor.name}</b> ( ${catalog.vendor.zipCode} ${catalog.vendor.city} )', t._( "Vendor" ) ), 3 );

		var contact = form.getElement("userId");
		form.removeElement( contact );
		form.addElement( contact, 4 );
		contact.required = true;

		return form;
    }
    
    /**
        Check input data when updating a catalog
    **/
    public static function checkFormData( catalog:db.Catalog, form:sugoi.form.Form ) {

		if(form.getValueOf("startDate").getTime() > form.getValueOf("endDate").getTime()){
			throw new Error("La date de début du contrat doit être avant la date de fin.");
		}

        //distributions should always happen between catalog dates
        if(form.getElement("startDate")!=null){
            for( distribution in catalog.getDistribs(false)){
                //accept a distrib on the last day of catalog
                var endDate =  DateTool.setHourMinute(form.getValueOf("endDate"),23,59);

                if(distribution.date.getTime() < form.getValueOf("startDate").getTime()){
                    throw new Error("Il y a des distributions antérieures à la date de début du catalogue");
                }
                if(distribution.date.getTime()> endDate.getTime()){
                    throw new Error("Il y a des distributions postérieures à la date de fin du catalogue");
                }
            }
        }
        
		var t = sugoi.i18n.Locale.texts;

		if( catalog.isVariableOrdersCatalog() ) {

			var orderStartDaysBeforeDistrib = form.getValueOf("orderStartDaysBeforeDistrib");
			if( orderStartDaysBeforeDistrib == 0 ) {
				throw new Error( 'L\'ouverture des commandes ne peut pas être à zéro.
				Si vous voulez utiliser l\'ouverture par défaut des distributions laissez le champ vide.');
			}
			
			//if( form.getValueOf("distribMinOrdersTotal")==0 && form.getValueOf("catalogMinOrdersTotal")==0 ){
			//	throw new Error("Vous devez définir un minimum de commande ( par distribution et/ou sur la durée du contrat )");
			//}

			//no absences datas if distribMinOrdersTotal=0
			if(form.getValueOf("distribMinOrdersTotal")==0){
				catalog.absencesEndDate = null;
				catalog.absencesStartDate = null;
				catalog.absentDistribsMaxNb = 0;
			}

			if(form.getValueOf("catalogMinOrdersTotal")>0){
				App.current.session.addMessage("Pensez à laisser suffisamment de distributions ouvertes à la commande pour que les membres puissent atteindre le minimum de commande de "+form.getValueOf("catalogMinOrdersTotal")+" €");
			}

			/*var catalogMinOrdersTotal = form.getValueOf("catalogMinOrdersTotal");
			var allowedOverspend = form.getValueOf("allowedOverspend");
			if( catalogMinOrdersTotal != null && catalogMinOrdersTotal != 0 && allowedOverspend == null ) {
				throw new Error( 'Vous devez obligatoirement définir un dépassement autorisé car vous avez rentré un minimum de commandes/provision minimale sur la durée du contrat.');
			}*/
		}

		if( catalog.isConstantOrdersCatalog() ) {
			
			var orderEndHoursBeforeDistrib = form.getValueOf("orderEndHoursBeforeDistrib");
			if( orderEndHoursBeforeDistrib == null || orderEndHoursBeforeDistrib == 0 ) {
				throw new Error( 'Vous devez obligatoirement définir un nombre d\'heures avant distribution pour la fermeture des commandes.');
			}
		}

		if ( catalog.id != null ) {

			if ( catalog.hasPercentageOnOrders() && catalog.percentageValue == null ) {
				throw new Error( t._("If you would like to add fees to the order, define a rate (%) and a label.") );
			}
			
			if ( catalog.hasStockManagement()) {

				for ( p in catalog.getProducts()) {
					if ( p.stock == null ) {
						App.current.session.addMessage(t._("Warning about management of stock. Please fill the field \"stock\" for all your products"), true );
						break;
					}
				}
			}
		}
	}

	public static function checkAbsences( catalog:db.Catalog ){

		var absentDistribsMaxNb = catalog.absentDistribsMaxNb;
		var absencesStartDate = catalog.absencesStartDate;
		var absencesEndDate = catalog.absencesEndDate;

		if ( ( absentDistribsMaxNb != null && absentDistribsMaxNb != 0 ) && ( absencesStartDate == null || absencesEndDate == null ) ) {
			throw new Error( 'Vous avez défini un nombre maximum d\'absences alors vous devez sélectionner des dates pour la période d\'absences.' );
		}

		if ( absencesStartDate != null && absencesEndDate != null ) {
			if ( absencesStartDate.getTime() >= absencesEndDate.getTime() ) {
				throw new Error( 'La date de début des absences doit être avant la date de fin des absences.' );
			}

			var absencesDistribsNb = AbsencesService.getContractAbsencesDistribs( catalog ).length;
			if ( absentDistribsMaxNb > 0 && absentDistribsMaxNb > absencesDistribsNb ) {
				throw new Error( 'Le nombre maximum d\'absences que vous avez saisi est trop grand.
				Il doit être inférieur ou égal au nombre de distributions dans la période d\'absences : ' + absencesDistribsNb );				
			}

			//edge case : if absence period == catalog period, check that absentDistribsMaxNb is less than all distribs number
			if(catalog.startDate.toString().substr(0,10)==absencesStartDate.toString().substr(0,10)){
				if(catalog.endDate.toString().substr(0,10)==absencesEndDate.toString().substr(0,10)){
					if ( absentDistribsMaxNb > 0  && absentDistribsMaxNb == absencesDistribsNb ) {
						throw new Error( 'Le nombre maximum d\'absences que vous avez saisi est trop grand.
						 Il doit être inférieur au nombre de distributions du contrat' );				
					}
				}	
			}


			if ( absencesStartDate.getTime() < catalog.startDate.getTime() || absencesEndDate.getTime() > catalog.endDate.getTime() ) {
				throw new Error( 'Les dates d\'absences doivent être comprises entre le début et la fin du contrat.' );
			}
		}
	}

	/**
		update future distribs start/end Order Dates
	**/
	public static function updateFutureDistribsStartEndOrdersDates( catalog : db.Catalog, newOrderStartDays : Int, newOrderEndHours : Int ) : String {

		if ( newOrderStartDays != null || newOrderEndHours != null ) {

			var futureDistribs = db.Distribution.manager.search( $catalog == catalog && $date > Date.now(), { orderBy : date }, true );
			for ( distrib in futureDistribs ) {

				if ( newOrderStartDays != null ) {	
					distrib.orderStartDate = DateTools.delta( distrib.date, -1000.0 * 60 * 60 * 24 * newOrderStartDays );
				}
	
				if ( newOrderEndHours != null ) {	
					distrib.orderEndDate = DateTools.delta( distrib.date, -1000.0 * 60 * 60 * newOrderEndHours );
				}

				distrib.update();				
			}

			var message = '<br/>Attention ! ';
			
			if ( newOrderStartDays != null && newOrderEndHours != null ) {
				message += 'Les nouveaux délais d\'ouverture et de fermeture de commande ont été appliqués à toutes les distributions à venir. 
				Si vous aviez personnalisé des dates d\'ouverture ou de fermeture, ces personnalisations ont été écrasées.';
			} else if ( newOrderStartDays != null ) {
				message += 'Le nouveau délai d\'ouverture de commande a été appliqué à toutes les distributions à venir. 
				Si vous aviez personnalisé des dates d\'ouverture, ces personnalisations ont été écrasées.';
			} else {
				message += 'Le nouveau délai de fermeture de commande a été appliqué à toutes les distributions à venir. 
				Si vous aviez personnalisé des dates de fermeture, ces personnalisations ont été écrasées.';
			}

			return message;
		}
		return null;
	}

}
