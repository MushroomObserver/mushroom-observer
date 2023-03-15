// Reusable events intended to be callable from html tags
var MOEvents = {}

MOEvents.alert = function (element) {
  console.log(element)
  alert(JSON.stringify(element));
}

MOEvents.whirly = function () {
  $("#mo_ajax_progress").modal('show');
}

MOEvents.savingWhirly = function () {
  // $('#mo_ajax_progress_caption').empty().append(
  //   $("<span>").text(translations.show_namings_saving + "... "),
  //   $("<span class='spinner-right mx-2'></span>")
  // );

  $("#mo_ajax_progress").modal('show');
}

MOEvents.rebindAutoComplete = function (type) {
  // var type = this.value
  alert(type)
  var filter_term = $("#filter_term");
  switch (type) {
    case "taxon":
      AUTOCOMPLETERS[$('#ur_taxon').data('uuid')].reuse(filter_term)
    case "where":
      AUTOCOMPLETERS[$('#ur_location').data('uuid')].reuse(filter_term)
    case "user":
      AUTOCOMPLETERS[$('#ur_user').data('uuid')].reuse(filter_term)
  }

}
