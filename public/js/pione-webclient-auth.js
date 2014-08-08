/* ============================================================ *
   PIONE Webclient - auth
 * ============================================================ */

(function () {
    PioneWebclient.Auth = {};
    var Auth = PioneWebclient.Auth;

    // Create a HEX digest string.
    Auth.createPasswordDigest = function(username, password) {
	return CryptoJS.SHA512(username + ":" + password).toString(CryptoJS.enc.Hex);
    };
}());
