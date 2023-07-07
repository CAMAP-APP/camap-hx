package controller;

class Attention extends Controller
{

	public function new() 
	{
		super();
		if (!app.user.canAccessAttention()) throw Redirect("/");
	}
	
	@tpl("attention/default.mtt")
	function doDefault() {}
	
}