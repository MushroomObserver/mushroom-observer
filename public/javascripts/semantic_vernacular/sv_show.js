/* Javascript helpers for the "show" page.
/*
/******************************************************************************/

jQuery.noConflict();

window.onload = function()
{
  // Add conform dialog to the "svd-show-li-item-delete-link" links.
  jQuery("a.svd-show-li-item-delete-link").each(function() {
    var href = jQuery(this).attr("href");
    jQuery(this).removeAttr("href");
    jQuery(this).click(function() {
      var confirm = window.confirm("This entry will be permanently deleted. "
        + "Do you want to continue?");
      if (confirm == true) {
        jQuery(this).attr("href", href);
      }
    });
  });

  // Toggle proposals for labels and definitions.
  jQuery("span.svd-show-proposals-expand")
    .click(org.mo.sv.show.toggleOtherProposalsCallback);

  // When the "svd-show-propose-label-button" button is clicked: pop up a new 
  // window to let the user to propose a new label.
  jQuery("button#svd-show-propose-label-button")
    .click(org.mo.sv.show.proposeNewLabelCallback);

  // When the "svd-show-propose-scientific-name-button" button is clicked: pop 
  // up a new window to let the user to propose a new scientific name.
  jQuery("button#svd-show-propose-scientific-name-button")
    .click(org.mo.sv.show.proposeNewScientificNameCallback);
};

// Toggle other proposals for labels and definitions on the "show" page.
org.mo.sv.show.toggleOtherProposalsCallback = function()
{
  jQuery(this).siblings("div.svd-show-proposals-toggle").toggle(function(){
    var span = jQuery(this).siblings("span.svd-show-proposals-expand")[0];
    span.innerHTML = (span.innerHTML == " [+] ")? " [-] " : " [+] ";
  });
};

// Callback function to propose a new label for an existing SVD.
org.mo.sv.show.proposeNewLabelCallback = function()
{
  // Build the dialog window for a new label proposal.
  org.mo.sv.show.buildProposalDialog();
  // Show other name proposals.
  var labels = jQuery("<ul></ul>")
    .append(jQuery("ul#svd-show-label-proposals li").clone());
  var content = jQuery("<div class=\"svd-show-dialog-content\"></div>")
    .append("<p>Propose a name for this Vernacular Description:</p>")
    .append("<input type=\"text\" id=\"svd-show-label-proposal-input\" />")
    .append("<button type=\"button\" id=\"svd-show-label-proposal-submit\">" 
      + "Submit</button>")
    .append("<p>Other name proposals:</p>")
    .append(labels);
  // Append the content to the dialog window.
  jQuery("div.svd-show-proposal-dialog").append(content);
  org.mo.sv.show.showProposalDialog();
  // Read the URI of this SVD.
    org.mo.sv.create.postData["svd"]["uri"] = jQuery("li#svd-show-uri p").text();
  // When the "svd-show-label-proposal-submit" button is clicked: check if the 
  // entered label has existed in the ontology, then send it to the backend to 
  // convert to RDF and insert into the triple store.
  jQuery("button#svd-show-label-proposal-submit").click(function() {
    var label = jQuery("input#svd-show-label-proposal-input").val()
    if (label == "")
      alert("You have input nothing!")
    else {
      org.mo.sv.create.postData["label"]["value"] = label;
      org.mo.sv.submitQuery(
        org.mo.sv.askLabel(org.mo.sv.create.postData["label"]["value"]),
        org.mo.sv.show.submitLabelProposalCallback);
    }
  });
};

// Callback function for submitting a new label proposal.
org.mo.sv.show.submitLabelProposalCallback = function(response)
{
  if (response["boolean"] == true) {
    alert("This name has been used. Please enter another one.");
    jQuery("input#svd-show-label-proposal-input").val("");
  }
  else {
    console.log(org.mo.sv.create.postData);
    org.mo.sv.show.submit();
  }
};

// Callback function to propose a new scientific name for an existing SVD.
org.mo.sv.show.proposeNewScientificNameCallback = function()
{
  // Build the dialog window for a new scientific name proposal.
  org.mo.sv.show.buildProposalDialog();
  // Show other name proposals.
  var scientific_names = jQuery("<ul></ul>")
    .append(jQuery("ul#svd-show-associated-scientific-names li").clone());
  var content = jQuery("<div class=\"svd-show-dialog-content\"></div>")
    .append("<p>"
      + "Propose an associated scientific name for this Vernacular Description:"
      + "</p>")
    .append("<input type=\"text\" "
      + "id=\"svd-show-scientific-name-proposal-input\" />")
    .append("<button type=\"button\" "
      + "id=\"svd-show-scientific-name-proposal-submit\">Submit</button>")
    .append("<p>Other associated scientific names :</p>")
    .append(scientific_names);
  // Append the content to the dialog window.
  jQuery("div.svd-show-proposal-dialog").append(content);
  org.mo.sv.show.showProposalDialog();
  // Read the URI of this SVD.
    org.mo.sv.create.postData["svd"]["uri"] = jQuery("li#svd-show-uri p").text();
  // When the "svd-show-label-proposal-submit" button is clicked: check if the 
  // entered label has existed in the ontology, then send it to the backend to 
  // convert to RDF and insert into the triple store.
  jQuery("button#svd-show-scientific-name-proposal-submit").click(function() {
    var scientific_name = 
      jQuery("input#svd-show-scientific-name-proposal-input").val();
    if ( scientific_name == "")
      alert("You have input nothing!")
    else {
      // Check if the input is duplicated
      var flag = false;
      jQuery.each(org.mo.sv.create.postData["scientific_names"], 
        function(i, val) {
          if (val["label"] == name) flag = true;
        });
      if (flag == true) {
        alert("You have already input this scientific name!");
        jQuery("input#svd-create-scientific-name").val("");
      }
      else {
        org.mo.sv.create.postData["scientific_names"]
          .push({"label": scientific_name});
        console.log(org.mo.sv.create.postData);
        org.mo.sv.show.submit();
      }
    }
  });
};

// Build the dialog box for proposing a new label for an existing SVD.
org.mo.sv.show.buildProposalDialog = function()
{
  // Build HTML.
  var dialog = jQuery("<div class=\"svd-show-proposal-dialog\"></div>")
    .append("<button type=\"button\" class=\"svd-show-dialog-close\">x</button>");
  var mask = jQuery("<div class=\"svd-show-dialog-mask\"></div>");
  jQuery("div#svd-show").parent().append(dialog).append(mask);
  // If user resizes the window, call the sizing function again.
  jQuery(window).resize(function () {
    if (jQuery("div.svd-show-proposal-dialog").is(":visible")) 
      org.mo.sv.show.showProposalDialog();       
  }); 
  // Close the dialog box when the user clicks on the mask.
  jQuery("div.svd-show-dialog-mask, button.svd-show-dialog-close")
    .click(function() {
      jQuery("div.svd-show-proposal-dialog, div.svd-show-dialog-mask")
        .hide();
    });
};

// Function for adjusting the size of the proposal dialog window.
org.mo.sv.show.showProposalDialog = function()
{
  var mask_height = jQuery(document).height();  
  var mask_width = jQuery(window).width();
  // Calculate the values for center alignment.
  var dialog_top =  
    (mask_height/3) - (jQuery("div.svd-show-proposal-dialog").height()/2);  
  var dialog_left = 
    (mask_width/2) - (jQuery("div.svd-show-proposal-dialog").width()/2); 
  // Assign values to the mask and dialog box.
  jQuery("div.svd-show-dialog-mask")
    .css({"height": mask_height, "width": mask_width})
    .show();
  jQuery("div.svd-show-proposal-dialog")
    .css({"top": dialog_top, "left": dialog_left})
    .show();
}

org.mo.sv.show.submit = function(input)
{
  //Post postData to backend to generate RDF.
  var post_url = "/semantic_vernacular/propose";
  var post_data = {"data": JSON.stringify(org.mo.sv.create.postData)};
  var post_callback = function(response) {
    console.log(response);
    if(response.message == "OK")
      alert("The proposal has been submitted!");
    else
      alert(response.value);
    window.location.reload();
  };
  org.mo.sv.ajax(post_url, "POST", post_data, post_callback);
  // Clear postData.
  org.mo.sv.clearPostData();
};