function radioAmount() {
  return Form.getInputs('donate_form','radio','donation[amount]').find(function(radio) { return radio.checked; }).value;
}

function enableOther() {
  current_value = radioAmount();
  if (current_value == "other")
    $("donation_other_amount").enable();
  else
    $("donation_other_amount").disable();
}

function transferAmount() {
  var val1 = radioAmount();
  var val2 = $("donation_other_amount").value;
  var val = val1 == "other" ? val2 : val1;
  $("amount").value = val;
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