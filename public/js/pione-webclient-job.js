/* ============================================================ *
   PIONE Webclient - job
 * ============================================================ */

(function () {
    PioneWebclient.Job = {};

    var Common = PioneWebclient.Common;
    var Job = PioneWebclient.Job;

    Job.init = function (id) {
	Job.id = id;

	// Do the action on loading the document.
	$(document).ready(function() {
	    // initialize the result
	    Job.result = {url: undefined};

	    // update sources
	    Job.updatePpgFile();
	    Job.updateInputFiles();

	    // update state
	    Job.updateStatus();

	    // update results
	    Job.updateResultFiles();

	    // setup click events
	    $("#start").on("click", function () {Job.start()});
	    $("#stop" ).on("click", function () {Job.stop()});
	    $("#clear").on("click", function () {Job.clear()});

	    Job.setFollowMessageLog(true);
	    $("#follow-message-log").on("click", function () {Job.toggleFollowMessageLog()});

	    Job.setupInteraction();
	    Job.setupChooser();
	    Job.setupDirectUploader();

	    $("#job-desc").on("focusout", function () {
		Job.updateJobDescription($("#job-desc").val());
	    });

	    $("#upload-result-file").on("click", function () {
		Job.uploadResultFile($("#result-file").val());
	    });

	    // connect websocket server
	    Job.io.connect();
	});
    };

    /* ------------------------------------------------------------ *
       Webclient Model and Operations
     * ------------------------------------------------------------ */

    Job.updatePpgFile = function () {
	var jqxhr = $.getJSON("/job/ppg/info/" + Job.id, function (info) {
	    var filename = info.filename;
	    var size = info.size;
	    var mtime = info.mtime;

	    $("#ppg-file").empty();
	    var record = $("<tr/>");
	    var link = $("<a/>").text(filename).attr("href", Job.ppgFileURL(filename));
	    $("<td/>").append(link).appendTo(record);
	    $("<td/>").text(size).appendTo(record);
	    $("<td/>").text(mtime).appendTo(record);
	    var opDel = $("<a/>").html("&times;");
	    opDel.on("click", function () {Job.deletePpgFile(filename)});
	    $("<td/>").append(opDel).appendTo(record);
	    $("#ppg-file").append(record);

	    // update status
	    Job.changeStateProcessable();
	});

	jqxhr.fail(function () {
	    $("#ppg-file").empty();
	    var record = $("<tr/>");
	    $("<td/>").text("No package").appendTo(record);
	    $("<td/>").text("-").appendTo(record);
	    $("<td/>").text("-").appendTo(record);
	    $("<td/>").text("-").appendTo(record);
	    $("#ppg-file").append(record);

	    // update status
	    Job.changeStateUnset();
	});
    };

    Job.updateInputFiles = function () {
	var jqxhr = $.getJSON("/job/inputs/info/" + Job.id, function (infos) {
	    $("#inputs").empty();

	    if (infos.length > 0) {
		_.each(infos, function(info) {
		    var filename = info.filename;
		    var size = info.size;
		    var mtime = info.mtime;

		    var record = $("<tr/>");
		    var link = $("<a/>").text(filename).attr("href", Job.inputFileURL(filename));
		    $("<td/>").append(link).appendTo(record);
		    $("<td/>").text(size).appendTo(record);
		    $("<td/>").text(mtime).appendTo(record);
		    var opDel = $("<a/>").html("&times;");
		    opDel.on("click", function () {Job.deleteInputFile(filename)});
		    $("<td/>").append(opDel).appendTo(record);
		    $("#inputs").append(record);
		});
	    } else {
		var record = $("<tr/>");
		$("<td/>").text("No inputs").appendTo(record);
		$("<td/>").text("-").appendTo(record);
		$("<td/>").text("-").appendTo(record);
		$("<td/>").text("-").appendTo(record);
		$("#inputs").append(record);
	    }
	});
    };

    Job.updateStatus = function () {
	$.getJSON("/job/info/" + Job.id, function (info) {
	    switch (info.status) {
	    case "unset":
		Job.changeStateUnset();
		break;
	    case "processable":
		Job.changeStateProcessable();
		break;
	    case "processing":
		Job.changeStateProcessing();
		break;
	    }
	});
    };

    Job.updateResultFiles = function () {
	$.getJSON("/job/results/info/" + Job.id, function (infos) {
	    $("#results").empty();

	    if (infos.length > 0 ) {
		infos = infos.sort(function (a, b) {
		    if (a.mtime == b.mtime) return 0;
		    if (a.mtime < b.mtime) return 1;
		    if (a.mtime > b.mtime) return -1;
		});

		_.each(infos, function(info) {
		    var filename = info.filename;
		    var size = info.size;
		    var mtime = info.mtime;

		    var record = $("<tr/>");
		    var download = $("<span>")
		    var directDownload = $("<a>").attr("href", Job.resultFileURL(filename)).text(filename);
		    download.append(directDownload);
		    download.append(" ");
		    var dropboxDownload = Dropbox.createSaveButton(Job.resultFileURL(filename), filename);
		    download.append(dropboxDownload);
		    $("<td/>").append(download).appendTo(record);
		    $("<td/>").text(size).appendTo(record);
		    $("<td/>").text(mtime).appendTo(record);
		    var opDel = $("<a/>").attr("href", "#").html("&times;");
		    opDel.on("click", function () {Job.deleteResultFile(filename)});
		    $("<td/>").append(opDel).appendTo(record);
		    $("#results").append(record);
		});
	    } else {
		var record = $("<tr/>");
		$("<td/>").text("No result files").appendTo(record);
		$("<td/>").text("-").appendTo(record);
		$("<td/>").text("-").appendTo(record);
		$("<td/>").text("-").appendTo(record);
		$("#results").append(record);
	    }
	});
    };

    Job.ppgFileURL = function (filename) {
	return "/job/ppg/get/" + Job.id + "/" + filename;
    };

    Job.inputFileURL = function (filename) {
	return "/job/input/get/" + Job.id + "/" + filename;
    };

    Job.resultFileURL = function (filename) {
	return "/job/result/get/" + Job.id + "/" + filename;
    };

    Job.deletePpgFile = function (filename) {
	$.ajax({
	    url: "/job/ppg/delete/" + Job.id + "/" + filename,
	    type: "GET",
	    success: Job.updatePpgFile
	});
    };

    Job.deleteInputFile = function (filename) {
	$.ajax({
	    url: "/job/input/delete/" + Job.id + "/" + filename,
	    type: "GET",
	    success: Job.updateInputFiles
	});
    };

    Job.deleteResultFile = function (filename) {
	$.ajax({
	    url: "/job/result/delete/"+ Job.id + "/" + filename,
	    type: "GET",
	    success: Job.updateResultFiles
	});
    };

    // Upload by file.
    Job.uploadByFile = function (type, file, fun) {
	// set the file as form data
	var formData = new FormData();
	formData.append("file", file);

	// post the file
	$.ajax({
	    url: "/job/" + type + "/upload/file/" + Job.id + "/" + encodeURI(file.name),
	    type: "POST",
	    data: formData,
	    processData: false,
	    contentType: false,
	    success: fun
	});
    };

    Job.uploadPpgByFile = function (file) {
	Job.uploadByFile("ppg", file, Job.updatePpgFile);
    };

    Job.uploadInputByFile = function (file) {
	Job.uploadByFile("input", file, Job.updateInputFiles);
    };

    // Upload a file as a URL.
    Job.uploadByURL = function (type, filename, url, fun) {
	$.ajax({
	    url: "/job/" + type + "/upload/url/" + Job.id + "/" + encodeURI(filename),
	    type: "POST",
	    data: {filename: filename, url: url},
	    success: fun
	});
    };

    Job.uploadPpgByURL = function (filename, url) {
	Job.uploadByURL("ppg", filename, url, Job.updatePpgFile);
    };

    Job.uploadInputByURL = function (filename, url) {
	Job.uploadByURL("input", filename, url, Job.updateInputFiles);
    };

    Job.uploadResultFile = function (url) {
	$.ajax({
	    url: "/job/inputs/upload/result/" + Job.id,
	    type: "POST",
	    data: {url: url},
	    success: Job.updateInputFiles
	});
    }

    Job.handlePpgFileSelect = function (event) {
	var files = event.target.files;
	Job.uploadPpgByFile(files[0]);
    };

    Job.handleInputFileSelect = function (event) {
	var files = event.target.files;
	_.each(files, function(file) {Job.uploadInputByFile(file)});
    };

    Job.setupDirectUploader = function () {
	$("#source-ppg-direct-uploader").change(Job.handlePpgFileSelect);
	$("#source-files-direct-uploader").change(Job.handleInputFileSelect);
    };

    Job.resetDirectUploader = function () {
	var clearFileInput = function (elt) {
	    elt.wrap("<form>").closest("form").get(0).reset();
	    elt.unwrap();
	};

	clearFileInput($("#source-ppg-direct-uploader"));
	clearFileInput($("#source-files-direct-uploader"));
    };

    // Setup Dropbox chooser actions.
    Job.setupChooser = function () {
	// PPG chooser
	$("#source-ppg-chooser").on("DbxChooserSuccess", function (res) {
	    var ppg = res.originalEvent.files[0];
	    Job.uploadPpgByURL(ppg.name, ppg.link);
	});

	// Source files chooser
	$("#source-files-chooser").on("DbxChooserSuccess", function (res) {
	    var files = res.originalEvent.files;
	    _.each(files, function(file) {Job.uploadInputByURL(file.name, file.link);});
	});
    };

    // Reset Dropbox's chooser buttons. I think this is irresponsible way, do you
    // know right manner of reset the buttons?
    Job.resetChooser = function () {
	var buttons = $(".dropbox-dropin-btn");
	buttons.removeClass("dropbox-dropin-success dropbox-dropin-error");
	buttons.addClass("dropbox-dropin-default");
    }

    // Enable or disable job start button.
    Job.enableStart = function (state) {
	Job.enableOperationButton(state, "#start");
    };

    // Enable or disable job stop button.
    Job.enableStop = function (state) {
	Job.enableOperationButton(state, "#stop");
    };

    // Enable or disable base directory clear button.
    Job.enableClear = function (state) {
	Job.enableOperationButton(state, "#clear");
    };

    // Enable or disable the button.
    Job.enableOperationButton = function (state, id) {
	$(id).disabled = state;
	$(id).toggleClass("disabled", !state);
    };

    // Show message log section or not.
    Job.showMessageLog = function (state) {
	if (state) {
	    Job.clearMessageLog();
	    $("#message-log").fadeIn();
	} else {
	    $("#message-log").fadeOut();
	    Job.clearMessageLog();
	}
    };

    // Clear message log contents.
    Job.clearMessageLog = function () {
	$("#message-log pre").empty();
    };

    // Scroll by adding a line of message log.
    Job.scrollByMessageLog = function () {
	if (Job.followMessageLog) {
	    var size = parseInt($("#message-log").css("line-height"));
	    scrollBy(0, size);
	}
    };

    // Set follow message log mode.
    Job.setFollowMessageLog = function (state) {
	Job.followMessageLog = state;
	$("#follow-message-log").toggleClass("follow", state);
    };

    // Toggle follow message log mode.
    Job.toggleFollowMessageLog = function () {
	Job.setFollowMessageLog(!Job.followMessageLog);
    };

    // Update job description.
    Job.updateJobDescription = function (text) {
	$.ajax({
	    url: "/job/desc/set/" + Job.id,
	    type: "POST",
	    data: {text: text},
	    success: function () {
		Job.showInfo("Updated description of this job.");
	    }
	});
    };

    /* ------------------------------------------------------------ *
       Websocket Handlers
       * ------------------------------------------------------------ */

    // Make a websocket connection.
    Job.io = new RocketIO();

    // Handle "connect" messages.
    Job.io.on("connect", function(data) {
	Job.connection = true;
	Job.setGoodJobStatus("Wait Request")
	Job.setGoodServerStatus("Connected");

	// join job id
	Job.io.push("join-job", {job_id: Job.id});
    });

    // Handle "disconnect" messages.
    Job.io.on("disconnect", function(data) {
	Job.connection = false;
	Job.setBadJobStatus("Disabled")
	Job.setBadServerStatus("Disconnected");
    });

    // Handle "error" messages.
    Job.io.on("error", function(data) {
	if (data.job_id != Job.id) return;

	Job.connection = false;
	Job.setBadJobStatus("Disabled")
	Job.setBadServerStatus("Disconnected");
    });

    // Handle "status" messages.
    Job.io.on("status", function(data) {
	if (data.job_id != Job.id) return;

	switch(data["name"]) {
	case "ACCEPTED":
	    Job.setGoodJobStatus("Queued");
	    Job.showSuccess("Your request has been accepted.");
	    break;
	case "BUSY":
	    Job.setBadJobStatus("Busy");
	    Job.showError("Server is busy now, please try again later.");
	    Job.changeStateProcessable();
	    break;
	case "PROCESSING":
	    Job.setGoodJobStatus("Processing");
	    Job.showInfo("Server is processing your job now.");
	    if ($("#message-log:visible").length == 0) {
		Job.showMessageLog(true);
	    }
	    break;
	case "PROCESS_ERROR":
	    Job.setBadJobStatus("Error");
	    Job.showError("PIONE failed to process your job.");
	    Job.changeStateProcessable();
	    break;
	case "ARCHIVING":
	    Job.setGoodJobStatus("Archiving");
	    Job.showInfo("Server is archiving the result of your job.");
	    break;
	case "COMPLETED":
	    Job.setGoodJobStatus("Completed");
	    Job.showSuccess("Your job has completed.");
	    Job.changeStateProcessable();
	    break;
	case "SHUTDOWN":
	    Job.setBadJobStatus("Shutdowned");
	    Job.showError("PIONE Webserver shutdowned. Please retry your job later, sorry.")
	    break;
	case "CANCELED":
	    Job.setGoodJobStatus("Wait Request");
	    Job.showInfo("Your job has been canceled.");
	    Job.changeStateProcessable();
	    break;
	}
    });

    // Handle "result" messages.
    Job.io.on("result", function(data) {
	if (data.job_id != Job.id) return;

	Job.updateResultFiles();
	Job.changeStateProcessable();
    });

    // Handle "message-log" messages.
    Job.io.on("message-log", function(data) {
	if (data.job_id != Job.id) return;

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
	Job.scrollByMessageLog();
    });

    // Handle "interaction-page" messages.
    Job.io.on("interaction-page", function(data) {
	if (data.job_id != Job.id) return;

	// activate page interaction
	Job.activatePageInteraction(true)

	$("#interaction-button").on("click", function () {
	    var win = window.open(data.url, "_blank");
	    win.focus();
	});
    });

    // Handle "interactive-dialog" messages.
    Job.io.on("interactive-dialog", function(data) {
	if (data.job_id != Job.id) return;

	// load contents
	Job.renderInteractiveOperationCanvas(data["content"]);

	// evaluate script
	eval(data["script"]);

	// start interactive operation
	Job.showInteractiveOperationCanvas();
    });

    Job.io.on("finish-interaction", function(data) {
	if (data.job_id != Job.id) return;

	// inactivate page interaction
	Job.activatePageInteraction(false);
    });

    /* ------------------------------------------------------------ *
       Job Handler
       * ------------------------------------------------------------ */

    // Send a job processing request.
    Job.start = function () {
	// send a request
	$.ajax({
	    url: "/job/start/" + Job.id,
	    type: "GET",
	    success: function () {
		Job.clearMessageLog();
		Job.changeStateProcessing();
	    }
	});
    };

    // Send a job cancel message.
    Job.stop = function () {
	$.ajax({
	    url: "/job/stop/" + Job.id,
	    type: "GET",
	    success: function () {
		Job.changeStateProcessable();
	    }
	});
    };

    // Send a clear operation.
    Job.clear = function () {
	// send a request
	$.ajax({
	    url: "/job/clear/" + Job.id,
	    type: "GET",
	    success: function () {
		Job.clearMessageLog();
		Job.showInfo("The job has been cleared.");
	    }
	});
    };

    /* ------------------------------------------------------------ *
       Job Status
     * ------------------------------------------------------------ */

    Job.changeStateProcessing = function () {
	Job.enableStart(false);
	Job.enableStop(true);
	Job.enableClear(false);
	Job.clearMessageLog();
    }

    Job.changeStateProcessable = function () {
	Job.enableStart(true);
	Job.enableStop(false);
	Job.enableClear(true);
	Job.io.push("cancel", {job_id: Job.id});
    }

    Job.changeStateUnset = function () {
	Job.enableStart(false);
	Job.enableStop(false);
	Job.enableClear(true);
    }

    /* ------------------------------------------------------------ *
       Alert Message
     * ------------------------------------------------------------ */

    // Show the alert message.
    Job.showAleart = function(type, header, msg) {
	var alert = $("<div/>", {class: "alert alert-" + type});
	alert.append($("<strong/>", {text: header, style: "padding-right: 1em;"}));
	alert.append($("<span/>", {text: msg}));
	alert.prependTo("#alert-box");
	$("#alert-box").fadeIn();
	setTimeout(function() {alert.fadeOut();}, 5000);
    };

    // Show the success message.
    Job.showSuccess = function(msg) {
	Job.showAleart("success", "Success", msg)
    };

    // Show the info message.
    Job.showInfo = function(msg) {
	Job.showAleart("info", "Info", msg)
    };

    // Show the warning message.
    Job.showWarning = function(msg) {
	Job.showAleart("warning", "Warning", msg)
    };

    // Show the error message.
    Job.showError = function(msg) {
	Job.showAleart("danger", "Error", msg)
    };

    /* ------------------------------------------------------------ *
       Job & Server Status
       * ------------------------------------------------------------ */

    // Set the job status.
    Job.setStatus = function (id, type, status) {
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
    Job.setGoodJobStatus = function (name) {
	Job.setStatus("#job-status", "good", name);
    };

    // Set the job status for bad situations.
    Job.setBadJobStatus = function (name) {
	Job.setStatus("#job-status", "bad", name);
    };

    // Set the job status for unknown situations.
    Job.setUnknownJobStatus = function (name) {
	Job.setStatus("#job-status", "unknown", name);
    };

    // Set the server status for good situations.
    Job.setGoodServerStatus = function(status) {
	Job.setStatus("#server-status", "good", status);
    };

    // Set the server status for bad situations.
    Job.setBadServerStatus = function(status) {
	Job.setStatus("#server-status", "bad", status)
    };

    // Set the server status for unknown situations.
    Job.setUnknownServerStatus = function(status) {
	Job.setStatus("#server-status", "unknown", status)
    };

    /* ------------------------------------------------------------ *
       Interaction
     * ------------------------------------------------------------ */

    Job.activatePageInteraction = function(state) {
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

    Job.setupInteraction = function () {
	$("#interaction-button").tooltip();
	$("#interaction-dialog").hide();
    };
}());
