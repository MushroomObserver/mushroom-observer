$(window).on('load', function () {
  $("#donation_other_amount").on('click', function () {
    $("#donation_amount_other")[0].checked = true;
  });
  $("#donation_other_amount").keyup(function () {
    this.value = this.value.replace(/[^0-9]/g, '');
  });
});
