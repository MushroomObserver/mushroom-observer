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

  static rebindAutoComplete(type) {
    // console.log(type)
    // var type = this.value
    const filter_term = document.getElementById("filter_term");
    const ur_clade_i = document.getElementById('ur_clade').dataset.uuid
    const ur_location_i = document.getElementById('ur_location').dataset.uuid
    const ur_user_i = document.getElementById('ur_user').dataset.uuid
    switch (type) {
      case "clade":
        AUTOCOMPLETERS[ur_clade_i].reuse_for(filter_term)
      case "region":
        AUTOCOMPLETERS[ur_location_i].reuse_for(filter_term)
      case "user":
        AUTOCOMPLETERS[ur_user_i].reuse_for(filter_term)
    }
  }
}
