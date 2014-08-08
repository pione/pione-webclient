/* ============================================================ *
   PIONE Webclient - common
 * ============================================================ */

// Define an application.
var PioneWebclient = {};

(function () {
    PioneWebclient.Common = {};
    var Common = PioneWebclient.Common;

    // Show the error message.
    Common.error = function (message) {
	$("#message").text("ERROR:" + message);
    };

    Common.errorHandler = function (xhr, status, error) {
	if (('' + xhr.status).substr(0, 1) == "4") {
	    Common.error(xhr.responseText);
	} else {
	    Common.error("Error has occured in server side.");
	}
    };
}());
