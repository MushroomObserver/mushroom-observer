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

    switch (type) {
      case "clade":
        AUTOCOMPLETERS[filter_term.dataset.uuid].swap("clade");
        // new MOAutocompleter({
        //   input_id: "filter_term",
        //   ajax_url: "/ajax/auto_complete/name_above_genus/@",
        //   collapse: 1
        // });
        break;
      case "region":
        AUTOCOMPLETERS[filter_term.dataset.uuid].swap("location");
        // new MOAutocompleter({
        //   input_id: "filter_term",
        //   ajax_url: "/ajax/auto_complete/location/@",
        //   collapse: 1
        // });
        break;
      case "user":
        AUTOCOMPLETERS[filter_term.dataset.uuid].swap("user");
        // new MOAutocompleter({
        //   input_id: "filter_term",
        //   ajax_url: "/ajax/auto_complete/user/@",
        //   collapse: 1
        // });
        break;
    }
  }
}
