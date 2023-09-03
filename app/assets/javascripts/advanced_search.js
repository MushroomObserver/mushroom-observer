$(document).on("ready turbo:load", function () {
  var disable_unused_filters = function () {
    var model = " " + $("#search_model").val() + " ";
    $("[data-role='filter']").each(function () {
      var models = " " + $(this).data("models") + " ";
      if (models.includes(model)) {
        $(this).removeClass("disabled");
        $(this).find("input").attr("disabled", null);
      } else {
        $(this).addClass("disabled");
        $(this).find("input").attr("disabled", "disabled");
      }
    });
  }

  $("#search_model").change(disable_unused_filters);
  disable_unused_filters();
});
