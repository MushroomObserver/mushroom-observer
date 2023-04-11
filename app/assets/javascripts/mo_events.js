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
  //   $("<i class="fa-solid fa-loader fa-spin fa-2xl"></i>")
  // );

  $("#mo_ajax_progress").modal('show');
}

MOEvents.rebindAutoComplete = function (type) {
  // var type = this.value
  // alert(type)
  var filter_term = $("#filter_term");
  switch (type) {
    case "clade":
      AUTOCOMPLETERS[$('#ur_clade').data('uuid')].reuse(filter_term)
    case "region":
      AUTOCOMPLETERS[$('#ur_location').data('uuid')].reuse(filter_term)
    case "user":
      AUTOCOMPLETERS[$('#ur_user').data('uuid')].reuse(filter_term)
  }
}
