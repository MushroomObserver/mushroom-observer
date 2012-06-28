// Javascript helpers for Semantic Vernacular module.

if (window.org == undefined || typeof(org) != "object") org = {};
if (org.mo == undefined || typeof(org.mo) != "object") org.mo = {};
if (org.mo.sv == undefined || typeof(org.mo.sv) != "object") org.mo.sv = {};
if (org.mo.sv.create == undefined || typeof(org.mo.sv.create) != "object") org.mo.sv.create = {};

org.mo.sv.create.displayInput = function()
{
  var div = jQuery("#input-display");
  div.children().remove();
  var ul = jQuery("<ul></ul>").css("margin-top", "20px");
  var selected = jQuery("#new-vernacular-description").find("option:selected");
  selected.each(function() {
    var li = jQuery("<li></li>")
             .append(jQuery(this).parent().attr("name") + ": " + 
                     jQuery(this).val());
    ul.append(li);
  });
  var clear = jQuery("<button type=\"button\">Clear</button>")
              .click(function(){
                div.children().remove();
              });
  var p = jQuery("<p><b>Your Input:</b></p>")
          .css({"float": "left", "margin-right": "25px"});
  div.append(p).append(clear).append(ul); 
  selected.removeAttr("selected");
}

org.mo.sv.create.toggleFeatureValues = function(id)
{
  var select = document.getElementById(id); 
  select.style.display = (select.style.display == "none")? "block" : "none";
  var span = jQuery(select).parent().find("span")[0];
  span.innerHTML = (span.innerHTML == " [+] ")? " [-] " : " [+] ";
}