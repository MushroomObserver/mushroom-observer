// Reusable events intended to be callable from html tags
class MOEvents {
  constructor() {
  }

  static alert(element) {
    console.log(element)
    alert(JSON.stringify(element));
  }

  static whirly(text) {
    $('#mo_ajax_progress_caption').html(text);
    $("#mo_ajax_progress").modal('show');
  }

  static swapFilterAutoComplete(type) {
    // console.log(type)
    // var type = this.value
    // Each autocompleter has a data-uuid that corresponds to its array index
    // in AUTOCOMPLETERS
    const filter_term = document.getElementById("filter_term");
    const autocompleter = AUTOCOMPLETERS[filter_term.dataset.uuid]

    switch (type) {
      case "clade":
        autocompleter.swap("clade");
        break;
      case "region":
        autocompleter.swap("location");
        break;
      case "user":
        autocompleter.swap("user");
        break;
    }
  }
}
