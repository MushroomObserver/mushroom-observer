var attach_suggestion_bindings;

function SuggestionModule(ids, url, text) {
  attach_suggestion_bindings = function () {
    var button = $("[data-role='suggest_names']");
    // var whirly = " <span class='spinner-right mx-2'></span>";

    button.on('click', function (event) {
      button.attr("disabled", "disabled");
      var progress = $("#mo_ajax_progress_caption")
        .html(text.suggestions_processing_images + "...");
      var progressModal = $("#mo_ajax_progress").modal("show");
      var resetModal = function () {
        progress.empty();
        progressModal.modal("hide");
        button.attr("disabled", null);
      }

      var results = [];
      var any_worked = false;
      var predict = function (i) {
        progress.html(text.suggestions_processing_image + " " +
          (i + 1) + " / " + ids.length + "...");
        $.ajax("https://images.mushroomobserver.org/model/predict", {
          method: "POST",
          data: { id: ids[i] },
          dataType: "text",
          async: true,
          complete: function (request) {
            if (request.status == 200) {
              results[i] = JSON.parse(request.responseText);
              any_worked = true;
            }
            if (i + 1 < ids.length) {
              predict(i + 1);
            } else if (any_worked) {
              progress.html(text.suggestions_processing_results + "...");
              var out = JSON.stringify(results);
              url = url.replace("xxx", encodeURIComponent(out));
              resetModal();
              if (event.ctrlKey)
                window.open(url, "_blank");
              else
                window.location.href = url;
            } else {
              progress.html(text.suggestions_error);
              window.setTimeout(function () {
                resetModal();
              }, 1000);
            }
          }
        });
      };
      predict(0);
    });
  };

  $(document).ready(attach_suggestion_bindings);
}
