// Reusable events intended to be callable from html tags
var MOEvents = {}

MOEvents.alert = function (element) {
  console.log(element)
  alert(JSON.stringify(element));
}

MOEvents.whirly = function (text) {
  $('#mo_ajax_progress_caption').html(text);
  $("#mo_ajax_progress").modal('show');
}

MOEvents.rebindAutoComplete = function (type) {
  // var type = this.value
  // alert(type)
  var filter_term = $("#filter_term");
  switch (type) {
    case "clade":
      AUTOCOMPLETERS[$('#ur_clade').data('uuid')].reuse(filter_term)
      break;
    case "region":
      AUTOCOMPLETERS[$('#ur_location').data('uuid')].reuse(filter_term)
      break;
    case "user":
      AUTOCOMPLETERS[$('#ur_user').data('uuid')].reuse(filter_term)
      break;
  }
}
