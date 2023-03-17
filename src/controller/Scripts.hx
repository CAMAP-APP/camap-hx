package controller;

/**
    this controller is meant for migration scripts to run from CLI
    "neko index.n /scripts/actionName"
**/
class Scripts extends Controller
{
	var now : Date;

	public function new(){
		super();

        if (sugoi.Web.isModNeko){
            throw "CLI only";
        }
	}

    function print(s:String){
        Sys.println(s);
    }

    public static function printTitle(title){
		Sys.println("==== "+title+" ====");
	}

	public function doDefault(){}
	
    /**
        2023-01-06
    **/
	public function doRecomputeBasketTotal(from:Date,to:Date){
        // var from = Date.fromString(from);
        // var to = Date.fromString(to);
       
		printTitle("Recompute basket total from "+from.toString()+" to "+to.toString());
        for(g in db.Group.manager.search($id>0,false)){
            var dids = db.MultiDistrib.getFromTimeRange( g , from , to  ).map(d -> d.id);
            print("group "+g.id+" has "+dids.length+" mds");
            var baskets = db.Basket.manager.search( $multiDistribId in dids );
            
            for ( b in baskets){
                print('basket #${b.id}');
                b.lock();
                b.total = b.getOrdersTotal();
                b.update();
            }
        }

	}

    /**
        2023-02-15 clean non AMAP data
    **/
    public function doCleannonamapdata(groupMinId:Int,userMinId:Int,vendorMinId:Int){

        // Delete non AMAP groups
        print("Delete "+db.Group.manager.count($flags.has(__ShopMode) && $id > groupMinId )+" groups");
        db.Group.manager.delete($flags.has(__ShopMode) && $id > groupMinId );

        // Delete users who have no UserGroup
        for ( u in db.User.manager.search($id > userMinId,true) ){

            var ug = db.UserGroup.manager.select( $user == u ,false);

            if(ug==null) {
                print("delete user #"+u.id);
                u.delete();
            }
        }

        // Delete vendors without catalogs
        for ( v in db.Vendor.manager.search($id > vendorMinId,true) ){

            if( v.getContracts().length == 0 ){
                print("delete vendor #"+v.id);
                v.delete();
            }
        }



    }

}
