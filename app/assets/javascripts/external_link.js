$(window).load(function () {
  $("[data-role='link-controls']").removeClass("hidden");

  $("[data-role='add-link']").click(function () {
    var site_id = $(this).data("id");
    alert("add link to site " + site_id);
  });

  $("[data-role='edit-link']").click(function () {
    var link_id = $(this).data("id");
    alert("edit link " + link_id);
  });

  $("[data-role='remove-link']").click(function () {
    var link_id = $(this).data("id");
    alert("remove link " + link_id);
  });
});
