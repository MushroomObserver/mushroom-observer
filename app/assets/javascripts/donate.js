function radioAmount() {
  return jQuery("input[type=radio]:checked", "#donate_form").val();
}

function enableOther() {
  jQuery("#donation_other_amount").prop("disabled", radioAmount() != "other");
}

function transferAmount() {
  var val1 = radioAmount();
  var val2 = jQuery("#donation_other_amount").val();
  var val = val1 == "other" ? val2 : val1;
  jQuery("#amount").val(val);
  document.cookie = "donation_amount=" + val;
  document.cookie = "who=" + $("donation_who").value
  document.cookie = "anon=" + $("donation_anonymous").checked
  document.cookie = "email=" + $("donation_email").value
}

function clearDonationCookies() {
  document.cookie = "donation_amount=";
  document.cookie = "who=";
  document.cookie = "anon=";
  document.cookie = "email=";
}
