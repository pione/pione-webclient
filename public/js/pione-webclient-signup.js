/* ============================================================ *
   PIONE Webclient - signup
 * ============================================================ */

(function () {
    PioneWebclient.Signup = {};
    var Signup = PioneWebclient.Signup;
    var Auth = PioneWebclient.Auth;
    var Common = PioneWebclient.Common;

    // Initialize signup logics.
    Signup.init = function () {
	$(document).ready(function() {
	    $("#form-signup").submit(Signup.submit);
	});
    };

    // Check password.
    Signup.checkPassword = function (password, confirmation) {
	return (password == confirmation);
    };

    // Do signup process.
    Signup.signup = function (username, password, confirmation) {
	if (Signup.checkPassword(password, confirmation)) {
	    var digest = Auth.createPasswordDigest(username, password);

	    $.ajax({
		url: "/auth/signup/" + encodeURI(username),
		type: "POST",
		data: {password: digest},
		success: function () {
		    // go next page
		    location.href = "/workspace";
		},
		error: function (xhr, status, error) {
		    if (('' + xhr.status).substr(0, 1) == "4") {
			Common.error(xhr.responseText);
		    } else {
			Common.error("unknown error")
		    }
		}
	    });
	} else {
	    Common.error(
		"Password and confirmation are mistached. Please input correct password."
	    );
	}
    };

    // Submit signup informations.
    Signup.submit = function (event) {
	event.preventDefault();
	var username = $("#username").val();
	var password = $("#password").val();
	var confirmation = $("#confirmation").val();
	Signup.signup(username, password, confirmation);
    };
}());
