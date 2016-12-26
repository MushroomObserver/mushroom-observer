$(window).load(function () {
  var other = $("#donation_other_amount").attr("disabled", "disabled");
  $("[name='donation[amount]'").change(function () {
    other.attr("disabled", "disabled");
  });
  $("#donation_amount_other").change(function () {
    other.attr("disabled", null);
  });
});
