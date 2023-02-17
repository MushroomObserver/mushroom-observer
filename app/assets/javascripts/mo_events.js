// Reusable events intended to be callable from html tags
var MOEvents = {}

MOEvents.alert = function (element) {
  console.log(element)
  alert(JSON.stringify(element));
}

MOEvents.whirly = function () {
  $("#naming_ajax_progress").modal('show');
}

MOEvents.savingWhirly = function () {
  // $('#naming_ajax_progress_caption').empty().append(
  //   $("<span>").text(translations.show_namings_saving + "... "),
  //   $("<span class='spinner-right mx-2'></span>")
  // );

  $("#naming_ajax_progress").modal('show');
}
