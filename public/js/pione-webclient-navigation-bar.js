/* ============================================================ *
   PIONE Webclient - navigation bar
 * ============================================================ */

(function () {
    PioneWebclient.Nav = {};
    var Nav = PioneWebclient.Nav;

    Nav.init = function () {
	$(document).ready(function() {
	    $("#nav-logout").on("click", Nav.logout);
	});
    };

    Nav.logout = function () {
	$.get("/auth/logout", function () {location.href = "/page/login"});
    };
}());
