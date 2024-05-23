package db;

import sys.db.Object;
import sys.db.Types;
import Common;

/**
 * For a product, ProductDistributionStock is the configuration of the stock for one period when StockTracking is "PerDistribution" and stockTrackingPerDistrib is "PerPeriod" or "FrequencyRule".
 * A period is a consecutive series of distribution from startDistribution to endDistribution.
 */
class ProductDistributionStock extends Object {
	public var id:SId;
	public var stockPerDistribution:Float;
	public var frequencyRatio:Int; // 1 means every time, 2 means 1 times out of 2, 3 means 1 times out of 3, etc.

	@hideInForms @:relation(productId) public var product:db.Product;
	@hideInForms @:relation(startDistributionId) public var startDistribution:db.Distribution;
	@hideInForms @:relation(endDistributionId) public var endDistribution:db.Distribution;

	public function new() {
		super();
		stock = 0;
		frequencyRatio = 1;
	}

	function check() {
		if (this.startDistribution.catalog.id != this.product.catalog.id) {
			throw new tink.core.Error("startDistribution catalog does not match the product catalog. Please ensure the selected Distrib catalog match the product catalog.");
		}
		if (this.endDistribution.catalog.id != this.product.catalog.id) {
			throw new tink.core.Error("endDistribution catalog does not match the product catalog. Please ensure the selected Distrib catalog match the product catalog.");
		}
	}

	override public function update() {
		check();
		super.update();
	}

	override public function insert() {
		check();
		super.insert();
	}

	public static function getLabels() {
		var t = sugoi.i18n.Locale.texts;
		return [
			"startDistribution" => t._("Starting distribution"),
			"endDistribution" => t._("Ending distribution"),
			"product" => t._("Produit"),
			"stockPerDistribution" => t._("Stock per distribution")
		];
	}
}
