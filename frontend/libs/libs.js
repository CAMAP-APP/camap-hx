//
// npm dependencies library
//
(function (scope) {
  "use-strict";
  scope.__registry__ = Object.assign({}, scope.__registry__, {
    //
    // list npm modules required in Haxe
    //
    react: require("react"),
    redux: require("redux"),
    "react-redux": require("react-redux"),
    "prop-types": require("prop-types"),
    "react-dom": require("react-dom"),
    "react-router": require("react-router"),
    "react-router-dom": require("react-router-dom"),
    "@material-ui/core": require("@material-ui/core"),
    "@material-ui/core/styles": require("@material-ui/core/styles"),
    "@material-ui/icons": require("@material-ui/icons"),
    "bootstrap.native": require("bootstrap.native"),
  });

  /*if (process.env.NODE_ENV !== 'production') {
      // enable React hot-reload
      require('haxe-modular');
    }*/
})(typeof $hx_scope != "undefined" ? $hx_scope : ($hx_scope = {}));
