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
  var filter_term = document.getElementById("filter_term");
  switch (type) {
    case "clade":
      AUTOCOMPLETERS[document.getElementById('ur_clade').dataset.uuid].reuse(filter_term)
    case "region":
      AUTOCOMPLETERS[document.getElementById('ur_location').dataset.uuid].reuse(filter_term)
    case "user":
      AUTOCOMPLETERS[document.getElementById('ur_user').dataset.uuid].reuse(filter_term)
  }
}
