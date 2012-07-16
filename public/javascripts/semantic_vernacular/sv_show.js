/* Javascript helpers for the SVD "show" page.
/*
/******************************************************************************/

jQuery.noConflict();

window.onload = function()
{
  // Append the dialog box for new label proposal.
  org.mo.sv.show.buildNewLabelProposalDialog();

  // Set CSS.
  org.mo.sv.show.setCSS();

  // Toggle other proposals for labels and definitions.
  jQuery("li.svd-other-proposals")
    .click(org.mo.sv.show.toggleOtherProposalsCallback);

  // When the "svd-show-propose-label" button is clicked: pop up a new window
  // to let the use enter a new label.
  jQuery("button#svd-show-propose-label")
    .click(org.mo.sv.show.proposeNewLabelCallback);
};

// Set CSS.
org.mo.sv.show.setCSS = function()
{
  jQuery("div.svd-navigation").css({
    "margin-top": "40px"
  });
  jQuery("div#svd-new-label-dialog").css({
    "-moz-border-radius": "5px",
    "-webkit-border-radius": "5px", 
    "background": "#eee",
    "position": "absolute",
    "z-index": "5000",
    "display": "none",
    "width": "780px",
    "height": "400px",
    "overflow": "scroll"
  });
  jQuery("div#svd-new-label-mask").css({ 
    "background": "#000",
    "filter": "alpha(opacity=50)", 
    "-moz-opacity": "0.5", 
    "-khtml-opacity": "0.5", 
    "opacity": "0.5",
    "width": "100%",
    "height": "100%",
    "position": "absolute",
    "top": "0",
    "left": "0",
    "z-index": "4000",
    "display": "none"
  });
  jQuery("div.svd-dialog-content").css({
    "padding": "30px",
    "overflow": "scroll"
  });
  jQuery("div.svd-dialog-content p").css({
    "margin": "15px 0px"
  })
  jQuery("button.svd-dialog-close").css({
    "margin-right": "6px",
    "color": "red",
    "font-size": "18px",
    "border": "none",
    "background": "#eee",
    "cursor": "pointer",
    "float": "right"
  });
  jQuery("li.svd-detail-li").css({
    "margin": "10px 0px"
  });
  jQuery("ul.svd-detail-li-item").css({
    "margin": "10px 0px" 
  });
  jQuery("li.svd-other-proposals").css({
    "cursor": "pointer"
  });
};

// Build the dialog box for proposing a new label for an existing SVD.
org.mo.sv.show.buildNewLabelProposalDialog = function()
{
  // Build HTML.
  var labels = jQuery("<ul></ul>")
    .append(jQuery("ul#svd-default-label li").clone())
    .append(jQuery("ul#svd-other-labels li").clone());
  var content = jQuery("<div class=\"svd-dialog-content\"></div>")
    .append("<p>Propose a new name for this Vernacular Description:</p>")
    .append("<input type=\"text\" id=\"svd-create-label\" />")
    .append("<button type=\"button\" id=\"svd-show-submit\">Submit</button>")
    .append("<p>Currently available names:</p>")
    .append(labels);
  var dialog = jQuery("<div id=\"svd-new-label-dialog\"></div>")
    .append("<button type=\"button\" class=\"svd-dialog-close\">x</button>")
    .append(content);
  var mask = jQuery("<div id=\"svd-new-label-mask\"></div>");
  jQuery("div#svd-show-detail").parent().append(dialog).append(mask);
  // If user resizes the window, call the callback again.
  jQuery(window).resize(function () {
    if (jQuery("div#svd-new-label-dialog").is(":visible")) 
      org.mo.sv.show.proposeNewLabelCallback();       
  }); 
  // Close the dialog box when the user clicks on the mask.
  jQuery("div#svd-new-label-mask, button.svd-dialog-close")
    .click(function() {
      jQuery("div#svd-new-label-dialog, div#svd-new-label-mask").hide();
    });
  // When the user enter something in the "svd-create-label" text box, put it
  // into inputData.
  jQuery("div#svd-new-label-dialog input#svd-create-label").change(function() {
    org.mo.sv.create.inputData["label"]["value"] = jQuery(this).val();
  });
  // When the "svd-show-submit" button is clicked: convert inputData to RDF, 
  // and then insert them into the triple store.
  jQuery("button#svd-show-submit").click(org.mo.sv.show.submitCallback);
};

// Callback function for clicking the "svd-show-submit" button in the 
// "svd-new-label-dialog" popup.
org.mo.sv.show.submitCallback = function()
{
  // Check if the entered label has existed in the ontology.
  var label = jQuery("div#svd-new-label-dialog input#svd-create-label").val();
  org.mo.sv.submitQuery(
    org.mo.sv.askLabel(label),
    org.mo.sv.show.askLabelCallback);
};

// Callback function for asking if a label input has existed in the ontology.
org.mo.sv.show.askLabelCallback = function(response)
{
  if (response["boolean"] == true) {
    alert("This name has been used. Please enter another one.");
    jQuery("div#svd-new-label-dialog input#svd-create-label").val("");
  }
  else {
    // Read the URI of this SVD.
    org.mo.sv.create.inputData["svd"]["uri"] = jQuery("li#svd-uri a").text();
    // Put the input into inputData.
    org.mo.sv.create.inputData["label"]["value"] = 
      jQuery("div#svd-new-label-dialog input#svd-create-label").val();
    console.log(org.mo.sv.create.inputData);
    //Post inputData to backend to generate RDF.
    var post_url = "/semantic_vernacular/submit";
    var post_data = {"data": JSON.stringify(org.mo.sv.create.inputData)};
    var post_callback = function(response) {
      console.log(response);
      if(response.message == "OK")
        alert("The new name has been added!");
      else
        alert(response.value);
      window.location.reload();
    };
    org.mo.sv.ajax(post_url, "POST", post_data, post_callback);
    // Clear inputData.
    org.mo.sv.clearInputData();  
  }
}

// Callback function to propose a new label for an existing SVD.
org.mo.sv.show.proposeNewLabelCallback = function()
{
  var mask_height = jQuery(document).height();  
  var mask_width = jQuery(window).width();
  // Calculate the values for center alignment.
  var dialog_top =  
    (mask_height/3) - (jQuery("div#svd-new-label-dialog").height()/2);  
  var dialog_left = 
    (mask_width/2) - (jQuery("div#svd-new-label-dialog").width()/2); 
  // Assign values to the mask and dialog box.
  jQuery("div#svd-new-label-mask")
    .css({"height": mask_height, "width": mask_width})
    .show();
  jQuery("div#svd-new-label-dialog")
    .css({"top": dialog_top, "left": dialog_left})
    .show();
};

// Toggle other proposals for labels and definitions on the "show" page.
org.mo.sv.show.toggleOtherProposalsCallback = function()
{
  jQuery(this).find("div.svd-other-proposals-toggle").toggle(function(){
    var span = jQuery(this).parent().find("span.svd-expand")[0];
    span.innerHTML = (span.innerHTML == " [+] ")? " [-] " : " [+] ";
  });
};