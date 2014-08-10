/* ============================================================ *
   PIONE Webclient - login
 * ============================================================ */

(function () {
    PioneWebclient.Login = {};
    var Login = PioneWebclient.Login;
    var Common = PioneWebclient.Common;
    var Auth = PioneWebclient.Auth;

    // Initialize signup logics.
    Login.init = function () {
	$(document).ready(function() {
	    $("#form-login").submit(Login.submit);
	});
    };

    // Submit login informations.
    Login.submit = function (event) {
	event.preventDefault();
	var username = $("#username").val();
	var password = $("#password").val();
	Login.login(username, password);
    };

    // Do signup process.
    Login.login = function (username, password) {
	var digest = Auth.createPasswordDigest(username, password);

	$.ajax({
	    url: "/auth/login/" + encodeURI(username),
	    type: "POST",
	    data: {password: digest},
	    success: function () {
		// go next page
		location.href = "/page/workspace/" + encodeURI(username);
	    },
	    error: function (xhr, status, error) {
		if (('' + xhr.status).substr(0, 1) == "4") {
		    Common.error(xhr.responseText);
		} else {
		    Common.error(xhr.responseText);
		}
	    }
	});
    };
}());
