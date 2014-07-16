/* ============================================================ *
   PIONE Webclient
 * ============================================================ */

// Define an application.
window.PioneWebclient = {};

// Set the job id.
PioneWebclient.setJobId = function(id) {
    PioneWebclient.jobId = id;
}

/* ------------------------------------------------------------ *
   Webclient Model and Operations
 * ------------------------------------------------------------ */

// Initialize the client model.
PioneWebclient.initModel = function () {
    // initialize the result
    PioneWebclient.result = {url: undefined};

    // update sources
    PioneWebclient.updateSources();

    // enable request button
    PioneWebclient.enableRequest(true);
};

// Update source files viewer.
PioneWebclient.updateSources = function() {
    $.getJSON(
	"/job/sources/" + PioneWebclient.jobId,
	function (info) {
	    // update ppg
	    $("#ppg-file").empty();
	    var ppg_record = $("<tr/>");
	    if (info.ppg != undefined) {
		var link = $("<a/>")
		    .text(info.ppg.filename)
		    .attr("href", PioneWebclient.inputFileUrl("ppg", info.ppg.filename));
		$("<td/>").append(link).appendTo(ppg_record);
		$("<td/>").text(info.ppg.size).appendTo(ppg_record);
		$("<td/>").text(info.ppg.mtime).appendTo(ppg_record);
		var op_delete = $("<a/>").html("&times;");
		op_delete.on("click", function () {
		    PioneWebclient.deleteInputFile("ppg", info.ppg.filename)
		});
		$("<td/>").append(op_delete).appendTo(ppg_record);
	    } else {
		$("<td/>").text("no package").appendTo(ppg_record);
		$("<td/>").text("-").appendTo(ppg_record);
		$("<td/>").text("-").appendTo(ppg_record);
		$("<td/>").text("-").appendTo(ppg_record);
	    }
	    $("#ppg-file").append(ppg_record);

	    // update sources
	    $("#sources").empty();
	    if (info.sources.length > 0) {
		_.each(info.sources, function(source) {
		    var source_record = $("<tr/>");
		    var link = $("<a/>")
			.text(source.filename)
			.attr("href", PioneWebclient.inputFileUrl("ppg", source.filename));
		    $("<td/>").append(link).appendTo(source_record);
		    $("<td/>").text(source.size).appendTo(source_record);
		    $("<td/>").text(source.mtime).appendTo(source_record);
		    var op_delete = $("<a/>").html("&times;");
		    op_delete.on("click", function () {
			PioneWebclient.deleteInputFile("source", source.filename)
		    });
		    $("<td/>").append(op_delete).appendTo(source_record);
		    $("#sources").append(source_record);
		});
	    } else {
		var source_record = $("<tr/>");
		$("<td/>").text("no sources").appendTo(source_record);
		$("<td/>").text("-").appendTo(source_record);
		$("<td/>").text("-").appendTo(source_record);
		$("<td/>").text("-").appendTo(source_record);
		$("#sources").append(source_record);
	    }
	}
    );
};

PioneWebclient.inputFileUrl = function (input_type, filename) {
    var jobId = PioneWebclient.jobId;
    return "/job/input/get/" + jobId + "/" + input_type + "/" + filename;
};

PioneWebclient.deleteInputFile = function (input_type, filename) {
    var jobId = PioneWebclient.jobId;
    $.ajax({
	url: "/job/input/delete/" + jobId + "/" + input_type + "/" + filename,
	type: "GET",
	success: PioneWebclient.updateSources
    });
};

// Upload by file.
PioneWebclient.uploadByFile = function (input_type, file) {
    // set the file as form data
    var fd = new FormData();
    fd.append("file", file);

    // post the file
    $.ajax({
	url: "/job/upload-by-file/" + input_type + "/" + PioneWebclient.jobId,
	type: "POST",
	data: fd,
	processData: false,
	contentType: false,
	success: PioneWebclient.updateSources
    });
}

// Upload a file as a URL.
PioneWebclient.uploadByUrl = function (input_type, filename, url) {
    $.ajax({
	url: "/job/upload-by-link/" + PioneWebclient.jobId,
	type: "POST",
	data: {input_type: input_type, filename: filename, url: url},
	success: PioneWebclient.updateSources
    });
}

PioneWebclient.handleFileSelect = function (input_type) {
    return function(event) {
	var files = event.target.files;

	switch (input_type) {
	case "ppg":
	    PioneWebclient.uploadByFile(input_type, files[0]);
	    break;
	case "sources":
	    _.each(files, function(file) {PioneWebclient.uploadByFile("source", file)});
	    break;
	}
    };
}

PioneWebclient.setupDirectUploader = function () {
    $("#source-ppg-direct-uploader").change(PioneWebclient.handleFileSelect("ppg"));
    $("#source-files-direct-uploader").change(PioneWebclient.handleFileSelect("sources"));
}

PioneWebclient.resetDirectUploader = function () {
    var clearFileInput = function (elt) {
	elt.wrap("<form>").closest("form").get(0).reset();
	elt.unwrap();
    };

    clearFileInput($("#source-ppg-direct-uploader"));
    clearFileInput($("#source-files-direct-uploader"));
}

// Setup Dropbox chooser actions.
PioneWebclient.setupChooser = function () {
    // PPG chooser
    $("#source-ppg-chooser").on("DbxChooserSuccess", function (res) {
	var ppg = res.originalEvent.files[0];
	PioneWebclient.uploadByUrl("ppg", ppg.name, ppg.link);
    });

    // Source files chooser
    $("#source-files-chooser").on("DbxChooserSuccess", function (res) {
	var files = res.originalEvent.files;
	_.each(files, function(file) {PioneWebclient.uploadByUrl("ppg", file.name, file.link);});
    });
};

// Reset Dropbox's chooser buttons. I think this is irresponsible way, do you
// know right manner of reset the buttons?
PioneWebclient.resetChooser = function () {
    var buttons = $(".dropbox-dropin-btn");
    buttons.removeClass("dropbox-dropin-success dropbox-dropin-error");
    buttons.addClass("dropbox-dropin-default");
}

// Enable or disable job request button.
PioneWebclient.enableRequest = function (state) {
    PioneWebclient.enableOperationButton(state, "#request");
};

// Enable or disable job cancel button.
PioneWebclient.enableCancel = function (state) {
    PioneWebclient.enableOperationButton(state, "#cancel");
};

// Enable or disable base directory clear button.
PioneWebclient.enableClear = function (state) {
    PioneWebclient.enableOperationButton(state, "#clear");
};

// Enable or disable the button.
PioneWebclient.enableOperationButton = function (state, id) {
    $(id).disabled = state;
    $(id).toggleClass("disabled", !state);
};

// Show message log section or not.
PioneWebclient.showMessageLog = function (state) {
    if (state) {
	PioneWebclient.clearMessageLog();
	$("#message-log").fadeIn();
    } else {
	$("#message-log").fadeOut();
	PioneWebclient.clearMessageLog();
    }
}

// Clear message log contents.
PioneWebclient.clearMessageLog = function () {
    $("#message-log pre").empty();
}

// Scroll by adding a line of message log.
PioneWebclient.scrollByMessageLog = function () {
    if (PioneWebclient.followMessageLog) {
	var size = parseInt($("#message-log").css("line-height"));
	scrollBy(0, size);
    }
}

// Set follow message log mode.
PioneWebclient.setFollowMessageLog = function (state) {
    PioneWebclient.followMessageLog = state;
    $("#follow-message-log").toggleClass("follow", state);
};

// Toggle follow message log mode.
PioneWebclient.toggleFollowMessageLog = function () {
    PioneWebclient.setFollowMessageLog(!PioneWebclient.followMessageLog);
};

// Show target section or not.
PioneWebclient.showTarget = function (state) {
    state ? $("#target").fadeIn() : $("#target").fadeOut();
};

// Update job description.
PioneWebclient.updateJobDescription = function (text) {
    $.ajax({
	url: "/job/desc/" + PioneWebclient.jobId,
	type: "POST",
	data: {text: text}
    });
};


// Clear the webclient.
PioneWebclient.clear = function () {
    PioneWebclient.initModel();
    PioneWebclient.resetChooser();
    PioneWebclient.resetDirectUploader();
    PioneWebclient.enableRequest(false);
    PioneWebclient.enableCancel(false);
    PioneWebclient.enableClear(true)
    PioneWebclient.showMessageLog(false);
    PioneWebclient.showTarget(false);
    if (PioneWebclient.connection) {
	PioneWebclient.setGoodJobStatus("Wait Request");
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

    // join job id
    if (PioneWebclient.mode == "job_operation") {
	PioneWebclient.io.push("join-job", {job_id: PioneWebclient.jobId});
    }
});

// Handle "disconnect" messages.
PioneWebclient.io.on("disconnect", function(data) {
    PioneWebclient.connection = false;
    PioneWebclient.setBadJobStatus("Disabled")
    PioneWebclient.setBadServerStatus("Disconnected");
});

// Handle "error" messages.
PioneWebclient.io.on("error", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

    PioneWebclient.connection = false;
    PioneWebclient.setBadJobStatus("Disabled")
    PioneWebclient.setBadServerStatus("Disconnected");
});

// Handle "status" messages.
PioneWebclient.io.on("status", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

    switch(data["name"]) {
    case "ACCEPTED":
	PioneWebclient.setGoodJobStatus("Queued");
	PioneWebclient.showSuccess("Your request was accepted.");
	PioneWebclient.enableCancel(true);
	break;
    case "BUSY":
	PioneWebclient.setBadJobStatus("Busy");
	PioneWebclient.showError("Server is busy now, please try again later.");
	break;
    case "START_FETCHING":
	PioneWebclient.setGoodJobStatus("Fetching");
	PioneWebclient.showInfo("PIONE is fetching your source files...");
	break;
    case "FETCH":
	PioneWebclient.setGoodJobStatus("Fetching " + data["number"] + "/" + data["total"]);
	break;
    case "END_FETCHING":
	PioneWebclient.setGoodJobStatus("Wait Processing");
	PioneWebclient.showSuccess("Your source files have been fetched.");
	break;
    case "FETCH_ERROR":
	PioneWebclient.setBadJobStatus("Error");
	PioneWebclient.showError("PIONE failed to fetch source files.");
	PioneWebclient.enableRequest(true);
	PioneWebclient.enableCancel(false);
	PioneWebclient.enableClear(true);
	break;
    case "START_PROCESSING":
	PioneWebclient.setGoodJobStatus("Processing");
	PioneWebclient.showInfo("PIONE starts processing your job.");
	if ($("#message-log:visible").length == 0) {
	    PioneWebclient.showMessageLog(true);
	}
	break;
    case "PROCESS_ERROR":
	PioneWebclient.setBadJobStatus("Error");
	PioneWebclient.showError("PIONE failed to process your job.");
	PioneWebclient.enableRequest(true);
	PioneWebclient.enableCancel(false);
	PioneWebclient.enableClear(true);
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
    case "CANCELED":
	PioneWebclient.setGoodJobStatus("Wait Request");
	PioneWebclient.showInfo("Your job canceled.");
	PioneWebclient.enableRequest(true);
	PioneWebclient.enableCancel(false);
	PioneWebclient.enableClear(true);
	break;
    }
});

// Handle "result" messages.
PioneWebclient.io.on("result", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

    var path = "/job/result/" + PioneWebclient.jobId + "/" + data["filename"];
    $("#target-saver").attr("href", path);
    $("#target-saver").attr("data-filename", data["filename"]);
    $("#target-download").attr("href", path);

    PioneWebclient.showTarget(true);
    PioneWebclient.enableRequest(true);
    PioneWebclient.enableCancel(false);
    PioneWebclient.enableCancel(true);
});

// Handle "message-log" messages.
PioneWebclient.io.on("message-log", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

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

    // follow logs
    PioneWebclient.scrollByMessageLog();
});

// Handle "interaction-page" messages.
PioneWebclient.io.on("interaction-page", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

    // activate page interaction
    PioneWebclient.activatePageInteraction(true)

    $("#interaction-button").on("click", function () {
	var win = window.open(data.url, "_blank");
	win.focus();
    });
});

// Handle "interactive-dialog" messages.
PioneWebclient.io.on("interactive-dialog", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

    // load contents
    PioneWebclient.renderInteractiveOperationCanvas(data["content"]);

    // evaluate script
    eval(data["script"]);

    // start interactive operation
    PioneWebclient.showInteractiveOperationCanvas();
});

PioneWebclient.io.on("finish-interaction", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

    // inactivate page interaction
    PioneWebclient.activatePageInteraction(false);
});

// Handle "requestable" messages.
PioneWebclient.io.on("requestable", function(data) {
    if (data.job_id != PioneWebclient.jobId) return;

    PioneWebclient.enableReuqest(true);
    PioneWebclient.enableCancel(false);
});


/* ------------------------------------------------------------ *
   Job Handler
 * ------------------------------------------------------------ */

// Send a job processing request.
PioneWebclient.sendRequest = function () {
    // send a request
    $.ajax({
	url: "/job/request/" + PioneWebclient.jobId,
	type: "GET",
	success: function() {
	    PioneWebclient.enableRequest(false);
	    PioneWebclient.enableClear(false);
	    $("#message-log pre").empty();
	    PioneWebclient.showTarget(false);
	}
    });
};

// Send a job cancel message.
PioneWebclient.sendCancel = function () {
    PioneWebclient.io.push("cancel", {job_id: PioneWebclient.jobId});
    PioneWebclient.enableCancel(false);
};

// Send a clear operation.
PioneWebclient.sendClear = function () {
    // send a request
    $.ajax({
	url: "/job/clear/" + PioneWebclient.jobId,
	type: "GET",
	success: function() {
	    PioneWebclient.enableRequest(false);
	    $("#message-log pre").empty();
	    PioneWebclient.showTarget(false);
	}
    });
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

// Set the job status for unknown situations.
PioneWebclient.setUnknownJobStatus = function (name) {
    PioneWebclient.setStatus("#job-status", "unknown", name);
};

// Set the server status for good situations.
PioneWebclient.setGoodServerStatus = function(status) {
    PioneWebclient.setStatus("#server-status", "good", status);
}

// Set the server status for bad situations.
PioneWebclient.setBadServerStatus = function(status) {
    PioneWebclient.setStatus("#server-status", "bad", status)
}

// Set the server status for unknown situations.
PioneWebclient.setUnknownServerStatus = function(status) {
    PioneWebclient.setStatus("#server-status", "unknown", status)
}

/* ------------------------------------------------------------ *
   Interaction
 * ------------------------------------------------------------ */

PioneWebclient.activatePageInteraction = function(state) {
    if (state) {
	$("#interaction-button").attr("data-original-title", "Go to interaction page!");
	$("#interaction-button").removeClass("inactive").addClass("active");
	$("#interaction-button").tooltip('show');
	setTimeout(function () {$("#interaction-button").tooltip('hide');}, 5000);
    } else {
	$("#interaction-button").attr("data-original-title", "No interaction.");
	$("#interaction-button").removeClass("active").addClass("inactive");
    }
};

PioneWebclient.setupInteraction = function () {
    $("#interaction-button").tooltip();
    $("#interaction-dialog").hide();
};


/* ------------------------------------------------------------ *
   Document Ready Actions
 * ------------------------------------------------------------ */

// Do the action on loading the document.
$(document).ready(function() {
    switch (PioneWebclient.mode) {
    case "job_operation":
	PioneWebclient.initModel();
	$("#request").on("click", function () {PioneWebclient.sendRequest()});
	$("#cancel").on("click", function () {PioneWebclient.sendCancel()});
	$("#clear").on("click", function () {PioneWebclient.sendClear()});

	PioneWebclient.setFollowMessageLog(true);
	$("#follow-message-log").on("click", function () {PioneWebclient.toggleFollowMessageLog()});

	PioneWebclient.setupInteraction();
	PioneWebclient.setupChooser();
	PioneWebclient.setupDirectUploader();

	$("#job-desc").on("focusout", function () {
	    PioneWebclient.updateJobDescription($("#job-desc").val());
	});

	// connect websocket server
	PioneWebclient.io.connect();
	break;
    }
});
