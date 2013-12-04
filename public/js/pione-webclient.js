/* ============================================================ *
   PIONE Webclient
 * ============================================================ */

// Define an application.
window.PioneWebclient = {};

/* ------------------------------------------------------------ *
   Webclient Model and Operations
 * ------------------------------------------------------------ */

// Initialize the client model.
PioneWebclient.initModel = function () {
    // initialize the source model
    PioneWebclient.source = {
	ppg: undefined,
	files: []
    };

    // initialize the result
    PioneWebclient.result = {url: undefined};

    // clear chooser names
    $("#source-ppg").text("");
    $("#source-files").text("");

    // disable request button
    PioneWebclient.enableRequest(false);
};

// Setup Dropbox chooser actions.
PioneWebclient.setupChooser = function () {
    // PPG chooser
    $("#source-ppg-chooser").on("DbxChooserSuccess", function (res) {
	var ppg = res.originalEvent.files[0];

	// register as a source PPG
	PioneWebclient.source.ppg = ppg.link;
	// show the PPG name
	$("#source-ppg").text(ppg.name);
	// enable request button
	PioneWebclient.enableRequest(true);
    });

    // Source files chooser
    $("#source-files-chooser").on("DbxChooserSuccess", function (res) {
	var files = res.originalEvent.files;
	var names = _.map(_.first(files, 3), function(file) {return file.name}).join(", ");
	if (files.length > 3) {
	    names = names + ", ..."
	}

	// register as source files
	PioneWebclient.source.files = _.map(files, function(file) {return file.link});
	// show source file names
	$("#source-files").text(names);
    });
};

// Reset Dropbox's chooser buttons. I think this is irresponsible way, do you
// know right manner of reset the buttons?
PioneWebclient.resetChooser = function () {
    var buttons = $(".dropbox-dropin-btn");
    buttons.removeClass("dropbox-dropin-success dropbox-dropin-error");
    buttons.addClass("dropbox-dropin-default");
}

// Enable or disable job request.
PioneWebclient.enableRequest = function (state) {
    $("#request").disabled = state;
    $("#request").toggleClass("disabled", !state);
};

// Show message log section or not.
PioneWebclient.showMessageLog = function (state) {
    if (state) {
	$("#message-log pre").empty();
	$("#message-log").fadeIn();
    } else {
	$("#message-log").fadeOut();
	$("#message-log pre").empty();
    }
}

// Show target section or not.
PioneWebclient.showTarget = function (state) {
    if (state) {
	$("#target").fadeIn();
    } else {
	$("#target").fadeOut();
    }
}

// Clear the webclient.
PioneWebclient.clear = function () {
    PioneWebclient.initModel();
    PioneWebclient.resetChooser();
    PioneWebclient.enableRequest(false);
    PioneWebclient.showMessageLog(false);
    PioneWebclient.showTarget(false);
    if (PioneWebclient.connection) {
	PioneWebclient.showGoodJobStatus("Wait Request");
    }
};

/* ------------------------------------------------------------ *
   Websocket Handlers
 * ------------------------------------------------------------ */

// Make a websocket connection.
PioneWebclient.io = new RocketIO();

// Handle "connect" messages.
PioneWebclient.io.on("connect", function(data) {
    PioneWebclient.connection = true;
    PioneWebclient.setGoodJobStatus("Wait Request")
    PioneWebclient.setGoodServerStatus("Connected");
});

// Handle "error" messages.
PioneWebclient.io.on("error", function(data) {
    PioneWebclient.connection = false;
    PioneWebclient.setBadJobStatus("Disabled")
    PioneWebclient.setBadServerStatus("Disconnected");
});

// Handle "status" messages.
PioneWebclient.io.on("status", function(name) {
    switch(name) {
    case "ACCEPTED":
	PioneWebclient.setGoodJobStatus("Queued");
	PioneWebclient.showSuccess("Your request was accepted.");
	break;
    case "BUSY":
	PioneWebclient.setGoodJobStatus("Rejected");
	PioneWebclient.showError("Server is busy now, please try again later.");
	break;
    case "START_FETCHING":
	PioneWebclient.setGoodJobStatus("Fetching");
	PioneWebclient.showInfo("PIONE is fetching your source files...");
	break;
    case "END_FETCHING":
	PioneWebclient.setGoodJobStatus("Wait Processing");
	PioneWebclient.showSuccess("Your source files have been fetched.");
	break;
    case "FETCH_ERROR":
	PioneWebclient.setBadJobStatus("Error");
	PioneWebclient.showError("PIONE failed to fetch source files.");
	break;
    case "START_PROCESSING":
	PioneWebclient.setGoodJobStatus("Processing");
	PioneWebclient.showInfo("PIONE starts processing your job.");
	if ($("#message-log:visible").length == 0) {
	    PioneWebclient.showMessageLog(true);
	}
	break;
    case "END_PROCESSING":
	PioneWebclient.setGoodJobStatus("Archiving");
	PioneWebclient.showInfo("PIONE finishes processing your job.");
	break;
    case "COMPLETED":
	PioneWebclient.setGoodJobStatus("Completed");
	PioneWebclient.showSuccess("Your job completed.");
	break;
    case "SHUTDOWN":
	PioneWebclient.setBadJobStatus("Shutdowned");
	PioneWebclient.showError("PIONE Webserver shutdowned. Please retry your job later, sorry.")
	break;
    }
});

// Handle "result" messages.
PioneWebclient.io.on("result", function(data) {
    var path = "result/" + data["uuid"] + "/" + data["filename"];

    $("#target").fadeIn();
    $("#target-saver").attr("href", path);
    $("#target-download").attr("href", path);
});

// Handle "message-log" messages.
PioneWebclient.io.on("message-log", function(data) {
    var area = $("#message-log pre");
    // level padding
    _(data["level"]).times(function(n) {area.append("  ")});
    // header padding
    var header = "";
    _(5 - data["header"].length).times(function(n) {header = header + " "});
    // header
    area.append($("<span/>", {text: header + data["header"], class: "header " + data["color"]}));
    area.append(" ");
    // content
    area.append($("<span/>", {text: data["content"], class: "content"}));
    area.append("\n");
});

/* ------------------------------------------------------------ *
   Job Handler
 * ------------------------------------------------------------ */

// Send a job processing request.
PioneWebclient.sendRequest = function () {
    PioneWebclient.io.push("request", PioneWebclient.source);
};

// Send a job cancel message.
PioneWebclient.sendCancel = function () {
    PioneWebclient.io.push("cancel");
};

/* ------------------------------------------------------------ *
   Alert Message
 * ------------------------------------------------------------ */

// Show the alert message.
PioneWebclient.showAleart = function(type, header, msg) {
    var alert = $("<div/>", {class: "alert alert-" + type});
    alert.append($("<strong/>", {text: header, style: "padding-right: 1em;"}));
    alert.append($("<span/>", {text: msg}));
    alert.prependTo("#alert-box");
    $("#alert-box").fadeIn();
    setTimeout(function() {alert.fadeOut();}, 5000);
};

// Show the success message.
PioneWebclient.showSuccess = function(msg) {PioneWebclient.showAleart("success", "Success", msg)}

// Show the info message.
PioneWebclient.showInfo = function(msg) {PioneWebclient.showAleart("info", "Info", msg)}

// Show the warning message.
PioneWebclient.showWarning = function(msg) {PioneWebclient.showAleart("warning", "Warning", msg)}

// Show the error message.
PioneWebclient.showError = function(msg) {PioneWebclient.showAleart("danger", "Error", msg)}

/* ------------------------------------------------------------ *
   Job & Server Status
 * ------------------------------------------------------------ */

// Set the job status.
PioneWebclient.setStatus = function (id, type, status) {
    // setup glyphicon name
    var glyphicon_name;
    switch (type) {
    case "good":
	glyphicon_name = "glyphicon-ok-sign";
	break;
    case "bad":
	glyphicon_name = "glyphicon-ban-circle";
	break;
    case "unknown":
	glyphicon_name = "glyphicon-question-sign";
	break;
    }

    // set glyphicon
    $(id + " span.glyphicon")
	.removeClass("glyphicon-question-sign glyphicon-ok-sign glyphicon-ban-circle")
	.addClass(glyphicon_name);

    // set status class
    $(id).removeClass("good bad unknown").addClass(type);

    // set status name
    $(id + " span.status-name").text(status);
};

// Set the job status for good situations.
PioneWebclient.setGoodJobStatus = function (name) {
    PioneWebclient.setStatus("#job-status", "good", name);
};

// Set the job status for bad situations.
PioneWebclient.setBadJobStatus = function (name) {
    PioneWebclient.setStatus("#job-status", "bad", name);
};

PioneWebclient.setGoodServerStatus = function(status) {
    PioneWebclient.setStatus("#server-status", "good", status);
}

PioneWebclient.setBadServerStatus = function(status) {
    PioneWebclient.setStatus("#server-status", "bad", status)
}

/* ------------------------------------------------------------ *
   Document Ready Actions
 * ------------------------------------------------------------ */

// Do the action on loading the document.
$(document).ready(function() {
    PioneWebclient.initModel();
    $("#request").on("click", function () {PioneWebclient.sendRequest()});
    $("#clear").on("click", function () {PioneWebclient.clear()});
    PioneWebclient.setupChooser();

    // connect websocket server
    PioneWebclient.io.connect();
});
