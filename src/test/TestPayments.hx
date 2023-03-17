package test;
import utest.Assert;
import service.PaymentService;
import service.OrderService;

/**
 * Test payments
 * 
 * @author web-wizard
 */
class TestPayments extends utest.Test
{
	
	public function new(){
		super();
	}
	
	function setup(){		
		TestSuite.initDB();
		TestSuite.initDatas();
		db.Basket.emptyCache();
	}
	
	function testValidateDistribution() {

		//Take a contract with payments enabled
		//Take 2 users and make orders for each
		var distrib = TestSuite.DISTRIB_LEGUMES_RUE_SAUCISSE;
		var contract = distrib.catalog;
		var product = TestSuite.COURGETTES;
		var francoisOrder = OrderService.make(TestSuite.FRANCOIS, 1, product, distrib.id);
		var francoisOrderOperation = PaymentService.onOrderConfirm([francoisOrder]);
		var sebOrder = OrderService.make(TestSuite.SEB, 3, product, distrib.id);
		var sebOrderOperation = PaymentService.onOrderConfirm([sebOrder]);
		//They both pay by check
		var francoisPayment = PaymentService.makePaymentOperation(TestSuite.FRANCOIS,contract.group, payment.Check.TYPE, product.price, "Payment by check", francoisOrderOperation[0]);
		var sebPayment      = PaymentService.makePaymentOperation(TestSuite.SEB,contract.group, payment.Check.TYPE, 3 * product.price, "Payment by check", sebOrderOperation[0] );	

		var md = distrib.multiDistrib;
		//Autovalidate this old distrib and check that all the payments are validated
		PaymentService.validateDistribution(md);
		
		//distrib should be validated
		Assert.isTrue(md.validated);
		
		//orders should be marked as paid
		Assert.isTrue(francoisOrder.paid);
		Assert.isTrue(sebOrder.paid);

		//order operation is NOT pending
		var francoisOperation = PaymentService.findVOrderOperation(francoisOrder.distribution.multiDistrib, TestSuite.FRANCOIS, false);
		var sebOperation 	  = PaymentService.findVOrderOperation(sebOrder.distribution.multiDistrib, TestSuite.SEB, false);		
		Assert.equals(francoisOperation.pending, false);
		Assert.equals(sebOperation.pending, false);

		//payment operation is NOT pending
		Assert.equals(francoisPayment.pending, false);
		Assert.equals(sebPayment.pending, false);

		//basket are validated 
		var b = db.Basket.get(TestSuite.SEB,distrib.multiDistrib);
		Assert.isTrue(b.isValidated());
		var b = db.Basket.get(TestSuite.FRANCOIS,distrib.multiDistrib);
		Assert.isTrue(b.isValidated());
	}

	function testMakeOnTheSpotPaymentOperations()
	{
		//Take a contract with payments enabled
		//Make 2 orders
		var distrib = TestSuite.DISTRIB_LEGUMES_RUE_SAUCISSE;
		var contract = distrib.catalog;
		var product1 = TestSuite.COURGETTES;
		var julieOrder1 = OrderService.make(TestSuite.JULIE, 1, product1, distrib.id);
		var julieOrderOperation1 = PaymentService.onOrderConfirm([julieOrder1]);
		
		//Payment on the spot
		var juliePayment1 = PaymentService.makePaymentOperation(TestSuite.JULIE,contract.group, payment.OnTheSpotPayment.TYPE, product1.price, "Payment on the spot", julieOrderOperation1[0]);

		var product2 = TestSuite.CARROTS;
		var julieOrder2 = OrderService.make(TestSuite.JULIE, 1, product2, distrib.id);
		var julieOrderOperation2 = PaymentService.onOrderConfirm([julieOrder2]);
		
		//Payment on the spot
		var juliePayment2 = PaymentService.makePaymentOperation(TestSuite.JULIE,contract.group, payment.OnTheSpotPayment.TYPE, product2.price, "Payment on the spot", julieOrderOperation2[0]);

		//Check that the second payment is just an update of the first one
		Assert.equals(juliePayment1.id, juliePayment2.id);
	}

}