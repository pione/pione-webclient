
function Params(name, data) {
    var label = $("<label/>").text(name);
    var input = $("<input>")
    $("#parameters")
}

var TypeSelector = new function() {
    TypeSelectorBox(parent) {
    this.select = $("<select/>").addClass("span6").attr("id", "processing-type");

    this.prototype = {
	build: function() {
	    $("<h2/>").text("Select processing type").appendTo($("#type-selector-box"));

	    // append select into the box
	    select.appendTo($("#type-selector-box"));

	// add empty option
	$("<option/>").appendTo(select);

	// add options
	$.get("processing-types", function(types) {_.each(types, makeOption);});

	// setup event
	select.change(changed);
    };

    makeOption: function (name) {
	$("<option/>").attr("label", name).attr("value", name).text(name).appendTo(select);
    },

    changed: function () {
	$.post("params", {name: select.val()}, function(data) {new Parameter(data);});
    }
}

$(document).ready(function(){
    typeSelectorBox.build();
});
