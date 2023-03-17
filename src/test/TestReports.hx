package test;import utest.Assert;
import Common;
import test.TestSuite;
import service.ReportService;
import service.OrderService;

/**
 * Test order reports
 * 
 * @author fbarbut
 */
class TestReports extends utest.Test
{
	
	public function new(){
			
		super();
	}

	function setup(){

		TestSuite.initDB();
		TestSuite.initDatas();

	}


	function testOrdersByProduct(){

		//record orders
		var seb = TestSuite.SEB;
		var francois = TestSuite.FRANCOIS;
		var julie = TestSuite.JULIE;

		//distrib de légumes
		var d = TestSuite.DISTRIB_LEGUMES_RUE_SAUCISSE;
		var carrots = TestSuite.CARROTS;
		var courgettes = TestSuite.COURGETTES;
		var potatoes = TestSuite.POTATOES;

		OrderService.make(seb,4,courgettes,d.id);
		OrderService.make(seb,1,potatoes,d.id);

		OrderService.make(francois,6,courgettes,d.id);
		OrderService.make(francois,2,potatoes,d.id);
		OrderService.make(francois,3,carrots,d.id);

		OrderService.make(julie,8,carrots,d.id);
		OrderService.make(julie,3,potatoes,d.id);

		//record orders on ANOTHER distrib
		var d2 = service.DistributionService.create(
			d.catalog,
			new Date(2018,2,12,0,0,0),
			new Date(2018,2,12,0,3,0),
			d.catalog.group.getPlaces().first().id,
			new Date(2018,2,8,0,0,0),
			new Date(2018,2,11,0,0,0)
		);
		OrderService.make(julie,6,carrots,d2.id);
		OrderService.make(julie,1,potatoes,d2.id);

		var orders = ReportService.getOrdersByProduct(d);

		//courgettes x 10
		var courgettesOrder = Lambda.find(orders, function(o) return o.pid==courgettes.id);
		Assert.equals( 10.0 , courgettesOrder.quantity );
		Assert.equals( 35.0 , courgettesOrder.totalTTC );
		Assert.equals( 33.18 , tools.FloatTool.clean(courgettesOrder.totalHT) );

		//the report stays the same, even if the product has a new price.
		courgettes.lock();
		courgettes.price+=4;
		courgettes.update();
		var orders = ReportService.getOrdersByProduct(d);
		var courgettesOrder = Lambda.find(orders, function(o) return o.pid==courgettes.id);
		Assert.equals( 10.0 , courgettesOrder.quantity );
		Assert.equals( 35.0 , courgettesOrder.totalTTC );
		Assert.equals( 33.18 , tools.FloatTool.clean(courgettesOrder.totalHT) );


	}
	
}