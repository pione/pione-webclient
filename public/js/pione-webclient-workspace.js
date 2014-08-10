/* ============================================================ *
   PIONE Webclient - workspace
 * ============================================================ */

(function () {
    PioneWebclient.Workspace = {};
    var Workspace = PioneWebclient.Workspace;
    var Common = PioneWebclient.Common;

    // Initialize signup logics.
    Workspace.init = function (username) {
	Workspace.username = username;

	$(document).ready(function() {
	    $("#form-new-job").submit(Workspace.submitNewJob);
	    Workspace.updateJobList();
	});
    };

    Workspace.submitNewJob = function (event) {
	event.preventDefault();
	var desc = $("#new-job-desc").val();
	Workspace.createNewJob(desc);
    };

    Workspace.createNewJob = function (desc) {
	$.ajax({
	    url: "/job/create",
	    type: "POST",
	    data: {desc: desc},
	    dataType: "json",
	    success: function (job) {
		// go job page
		location.href = "/page/job/" + job.id;
	    },
	    error: Common.errorHandler
	});
    };

    Workspace.updateJobList = function () {
	$.ajax({
	    url: "/workspace/jobs/info/" + encodeURI(Workspace.username),
	    type: "GET",
	    dataType: "json",
	    success: Workspace.updateTableByJobs,
	    error: Common.errorHandler
	});
    };

    Workspace.updateTableByJobs = function (jobs) {
	var tableBody =  $("#job-list-table-body");

	// clear table body
	tableBody.empty();

	// create rows
	_.each(jobs, function (job) {
	    tableBody.append(Workspace.createTableRowByJob(job));
	});
    }

    Workspace.createTableRowByJob = function (job) {
	var deleteJob = $("<a>").attr("href", "#").text("delete");
	deleteJob.on("click", function () {
	    $.ajax({
		url: "/job/delete/" + job.id,
		type: "GET",
		success: Workspace.updateJobList,
		error: Common.errorHandler
	    });
	});

	var cellId = $("<td>").append($("<a>").attr("href", "/page/job/" + job.id).text(job.id));
	var cellDesc = $("<td>").append($("<a>").attr("href", "/page/job/" + job.id).text(job.desc));
	var cellCtime = $("<td>").text(job.ctime);
	var cellMtime = $("<td>").text(job.mtime);
	var cellStatus = $("<td>").text(job.status);
	var cellDelete = $("<td>").append(deleteJob);

	return $("<tr>")
	    .append(cellId)
	    .append(cellDesc)
	    .append(cellCtime)
	    .append(cellMtime)
	    .append(cellStatus)
	    .append(cellDelete);
    }
}());
