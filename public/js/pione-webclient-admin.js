/* ============================================================ *
   PIONE Webclient - admin
 * ============================================================ */

(function () {
    PioneWebclient.Admin = {};
    var Admin = PioneWebclient.Admin;
    var Common = PioneWebclient.Common;

    // Initialize signup logics.
    Admin.init = function () {
	$(document).ready(function() {
	    Admin.updateUsers();

	    $("#workspace-title").on("focusout", function () {
		Admin.updateWorkspaceTitle($("#workspace-title").val());
	    });
	});
    };

    Admin.updateUsers = function () {
	$.ajax({
	    url: "/workspace/users/info",
	    type: "GET",
	    dataType: "json",
	    success: Admin.updateTableByUsers,
	    error: Common.errorHandler
	});
    };

    Admin.updateTableByUsers = function (users) {
	var tableBody =  $("#users-table-body");

	// clear table body
	tableBody.empty();

	// create rows
	users = users.sort(function (a, b) {
	    if (a.name == b.name) return 0;
	    if (a.name < b.name) return -1;
	    return 1;
	});
	_.each(users, function (user) {
	    tableBody.append(Admin.createTableRowByUser(user));
	});
    };

    Admin.createTableRowByUser = function (user) {
	var delOp = $("<a>").attr("href", "#").text("delete");
	delOp.on("click", function () {
	    $.ajax({
		url: "/user/delete/" + encodeURI(user.name),
		type: "GET",
		success: Admin.updateUsers,
		error: Common.errorHandler
	    });
	});

	var cellName = $("<td>").append($("<a>").attr("href", "/page/workspace/" + encodeURI(user.name)).text(user.name));
	var cellCtime = $("<td>").text(user.ctime);
	var cellMtime = $("<td>").text(user.mtime);
	var cellAdmin = $("<td>").text(user.admin ? "Yes" : "No");
	var cellDelete = $("<td>").append(delOp);

	return $("<tr>")
	    .append(cellName)
	    .append(cellCtime)
	    .append(cellMtime)
	    .append(cellAdmin)
	    .append(cellDelete);
    };

    // Update workspace title.
    Admin.updateWorkspaceTitle = function (title) {
	$.ajax({
	    url: "/workspace/title/set",
	    type: "POST",
	    data: {text: title},
	});
    };
}());

