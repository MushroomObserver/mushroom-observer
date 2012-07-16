/* Javascript helpers for the SVD "create" page.
/*
/******************************************************************************/

jQuery.noConflict();

window.onload = function()
{
  // Set CSS.
  org.mo.sv.create.setCSS();

  // If this is a new denifination proposal, put the passed URI into inputData. 
  if (jQuery("span#svd-create-uri").length > 0) {
    org.mo.sv.create.inputData["svd"]["uri"] 
      = jQuery("span#svd-create-uri").text();
  }

  // When the user enter something in the "svd-create-label" text box, put it
  // into inputData.
  jQuery("input#svd-create-label").change(function() {
    org.mo.sv.create.inputData["label"]["value"] = jQuery(this).val();
  });

  // Display all independent features in the "svd-create-feature" drop-down list.
  org.mo.sv.submitQuery(
    org.mo.sv.create.queryIndependentFeatures(), 
    org.mo.sv.create.getFeaturesCallback);

  // Display all values for a selected feature in the "svd-feature-value" 
  // multiple select box.
  jQuery("select#svd-create-feature").change(function() {
    var feature = jQuery(this).find("option:selected").val();
    org.mo.sv.submitQuery(
      org.mo.sv.create.queryFeatureValues(feature), 
      org.mo.sv.create.getFeatureValuesCallback);
  });

  // When the "svd-add-feature" button is clicked: store selected feature-value
  // pairs and available SVDs to inputData, display selected feature-value pairs
  // and available SVDs. 
  jQuery("button#svd-add-feature")
    .click(org.mo.sv.create.addFeatureCallback);

  // When the "svd-clear-feature" button is clicked: reset the "svd-feature" 
  // drop-down list, clear inputData["features"] and inputData["matched_svds"], 
  // and clear the display area.
  jQuery("button#svd-clear-feature")
    .click(org.mo.sv.create.clearFeatureCallback);

  // When the "svd-add-scientific-name" button is clicked: display the input and
  // put it into inputData["scientific_names"].
  jQuery("button#svd-add-scientific-name")
    .click(org.mo.sv.create.addScientificNameCallback);

  // When the "svd-clear-scientific-name" button is clicked: clear the display
  // area and inputData["scientific_names"].
  jQuery("button#svd-clear-scientific-name")
    .click(org.mo.sv.create.clearScientificNameCallback);

  // When the "svd-create-submit" button is clicked: convert inputData to RDF, 
  // and then insert them into the triple store.
  jQuery("button#svd-create-submit").click(org.mo.sv.create.submitCallback);
};

// Set CSS.
org.mo.sv.create.setCSS = function()
{
  jQuery("div.svd-navigation").css({
    "margin-top": "40px"
  });
  jQuery("div#svd-create-input").css({
    "float": "left",
    "margin": "10px 60px 0px 0px",
    "height": jQuery(window).height
  });
  jQuery("div#svd-create-input table").css({
    "border-spacing": "10px"
  });
  jQuery("div#svd-create-display ul").css({
    "margin-top": "30px"
  });
  jQuery("div.svd-create-display-header").css({
    "display": "none",
  });
  jQuery("div.svd-create-display-header span").css({
    "font-size": "14px",
  });
  jQuery("div#svd-create-input input[type='text']").css({
    "width": "160px"
  });
  jQuery("div#svd-create-input select").css({
    "width": "165px",
  });
};

// Callback function for clicking the "svd-create-submit" button.
org.mo.sv.create.submitCallback = function()
{
  // Label and definition must be filled for a new SVD creation.
  if (org.mo.sv.create.inputData["svd"]["uri"] == null && ( 
      org.mo.sv.create.inputData["label"]["value"] == null ||
      org.mo.sv.create.inputData["features"].length == 0))
    alert("Both \"Proposed Name\" and \"Definition\" must be filled!");
  // Definition must be filled for a new definition proposal.
  else if (org.mo.sv.create.inputData["svd"]["uri"] && 
      org.mo.sv.create.inputData["features"].length == 0)
    alert("\"Definition\" must be filled!");
  else {
    // When inputData["svd"] has any SVD that is currently available, remind the
    // user his/her input of definition is not a new one.
    if (org.mo.sv.create.inputData["matched_svds"][0] != "none")
      alert("Your input of definition has matched one or more current" + 
        "vernacular desctiptions in the database, please refine your input!");
    else {
      console.log(org.mo.sv.create.inputData);
      //Post inputData to backend to generate RDF.
      var post_url = "/semantic_vernacular/submit";
      var post_data = {"data": JSON.stringify(org.mo.sv.create.inputData)};
      var post_callback = function(response) {
        console.log(response);
      if(response.message == "OK")
        alert("The new entry has been added!");
      else
        alert(response.value);
      window.location.href = "/semantic_vernacular/show?uri="
        + encodeURIComponent(response.page_uri);
      };
      org.mo.sv.ajax(post_url, "POST", post_data, post_callback);
      //Clear inputData.
      org.mo.sv.clearInputData();
    }
  }
};

// Callback function for clicking the "svd-clear-scientific-name" button.
org.mo.sv.create.clearScientificNameCallback = function()
{
  // Clear the display area.
  var ul = jQuery("ul#svd-scientific-name-display");
  ul.find("div.svd-create-display-header").hide()
  ul.find("li").remove();
  // Clear the input box.
  jQuery("input#svd-create-scientific-name").val("");
  // Clear inputData["scientific_names"].
  org.mo.sv.create.inputData["scientific_names"] = [];
  //console.log(org.mo.sv.create.inputData);
};

// Callback funtion for clicking the "svd-add-scientific-name" button.
org.mo.sv.create.addScientificNameCallback = function()
{
  // Check if the input is empty
  var name = jQuery("input#svd-create-scientific-name").val();
  if (name == "")
    alert("You have not input any scientific name!");
  else {
    // Check if the input is duplicated
    var flag = false;
    jQuery.each(org.mo.sv.create.inputData["scientific_names"], 
      function(i, val) {
        if (val["value"] == name) flag = true;
      });
    if (flag == true) {
      alert("You have input this scientific name!");
      jQuery("input#svd-create-scientific-name").val("");
    }
    else {
      // Display the input.
      var ul = jQuery("ul#svd-scientific-name-display");
      ul.find("div.svd-create-display-header").show();
      ul.append("<li>" + name + "</li>");
      // Store the input into inputData["scientific_names"].
      var obj = {"id": null, "uri": null, "label": name};
      org.mo.sv.create.inputData["scientific_names"].push(obj);
      // Clear the "svd-create-scientific-name" input box.
      jQuery("input#svd-create-scientific-name").val("");
      //console.log(org.mo.sv.create.inputData);
    }
  }
};

// Callback function for clicking the "svd-clear-feature" button.
org.mo.sv.create.clearFeatureCallback = function()
{
  // Reset the "svd-feature" drop-down list to show all independent features.
  jQuery("select#svd-create-feature")
    .children().not(".svd-feature-select-default").remove();
  jQuery("select#svd-create-feature-value").children().remove();
  org.mo.sv.submitQuery(
    org.mo.sv.create.queryIndependentFeatures(), 
    org.mo.sv.create.getFeaturesCallback);
  // Clear inputData["features"] and inputData["matched_svds"].
  org.mo.sv.create.inputData["features"] = [];
  org.mo.sv.create.inputData["matched_svds"] = [];
  // Clear the display area.
  var ul = jQuery("ul#svd-available-svd");
  ul.find("li").remove();
  ul.find("div.svd-create-display-header").hide();
  ul = jQuery("ul#svd-feature-value-display");
  ul.find("li").remove()
  ul.find("div.svd-create-display-header").hide();
  //console.debug(org.mo.sv.create.inputData);
};

// Callback function for clicking the "svd-add-feature" button.
org.mo.sv.create.addFeatureCallback = function()
{
  var feature = 
    jQuery("select#svd-create-feature").find("option:selected").val();
  var feature_label = 
    jQuery("select#svd-create-feature").find("option:selected").text();
  var values = [];
  var value_labels = [];
  jQuery("select#svd-create-feature-value")
    .find("option:selected").each(function() {
      values.push(jQuery(this).val());
      value_labels.push(jQuery(this).text());
    });
  if (feature == "" || values.length == 0) 
    alert("No value selected!");
  else
  {
    // Put selected feature-value pairs to inputData["features"].
    var obj = {"feature": feature, "values": values};
    org.mo.sv.create.inputData["features"].push(obj);
    // Display selected feature-value pairs in the display area.
    var ul = jQuery("ul#svd-feature-value-display");
    if (ul.find("div.svd-create-display-header").css("display") == "none")
      ul.find("div.svd-create-display-header").show();
    ul.append("<li>" + feature_label + ": " 
      + value_labels.join(" <i>or</i> ") + "</li>");
    // Display available SVDs based on feature selections in the display area.
    org.mo.sv.submitQuery(
      org.mo.sv.create.querySVDForFeatureValue(feature, values), 
      org.mo.sv.create.getAvailableSVDsCallback);
    // Add features dependent on the previously selected feature-value pairs in 
    // the "svd-feature" drop-down list.
    org.mo.sv.submitQuery(
      org.mo.sv.create.queryDependentFeatures(feature, values), 
      org.mo.sv.create.getFeaturesCallback);
    // Clear "svd-feature-value" multiple select box. 
    jQuery("select#svd-create-feature-value").children().remove();
  }
  //console.log(org.mo.sv.create.inputData);
};

// Callback funtion for displaying available SVDs based on selected feature-
// value pairs.
org.mo.sv.create.getAvailableSVDsCallback = function(response)
{
  var uris = {};
  var labels = [];
  jQuery.each(response["results"]["bindings"], function(i, val) {
    var key = val["label"]["value"];
    uris[key] = val["uri"]["value"];
    labels.push(val["label"]["value"]);
  });
  var ul = jQuery("ul#svd-available-svd");
  if (ul.find("div.svd-create-display-header").css("display") == "none")
      ul.find("div.svd-create-display-header").show();
  if (labels.length == 0) {
    org.mo.sv.create.inputData["matched_svds"] = [];
    org.mo.sv.create.inputData["matched_svds"][0] = "none";
  }
  // If this is the first feature-value pair added, just show whatever SVD that 
  // mathch that pair.
  if (org.mo.sv.create.inputData["matched_svds"].length == 0) {
    jQuery.each(labels, function(i, val) {
      org.mo.sv.create.inputData["matched_svds"].push(val);
      ul.append("<li><a href=\"/semantic_vernacular/show?uri=" 
        + encodeURIComponent(uris[val]) 
        + "\">" + val + "</a></li>");
    });
  }
  // If previously added feature-value pairs don't match any SVD, no SVD will 
  // show for the newly added pair.
  else if (org.mo.sv.create.inputData["matched_svds"][0] == "none") {
    ul.find("li").remove();
    ul.append("<li>None.</li>");
  }
  // If previously added feature-value pairs have matched SVDs, show the 
  // intersection of the previous SVDs and the SVDs matching the new pair.
  else {
    // Remove any SVD in inputData["matched_svds"] that doesn't match the newly added
    // feature-value pair.
    org.mo.sv.create.inputData["matched_svds"] = 
      jQuery.map(org.mo.sv.create.inputData["matched_svds"], function(ele) {
        if (jQuery.inArray(ele, labels) == -1) {
          org.mo.sv.create.inputData["matched_svds"] = jQuery.grep(
            org.mo.sv.create.inputData["matched_svds"], function(value) {
              return value != ele;
          });
          return null;
        }
        else 
          return ele;
    });
    // If nothing is left in inputData["matched_svds"], it means no SVD match 
    // the new pair.
    if (org.mo.sv.create.inputData["matched_svds"].length == 0) {
      org.mo.sv.create.inputData["matched_svds"][0] = "none";
      ul.find("li").remove();
      ul.append("<li>None.</li>");
    }
    // The SVDs left are those match all the added pairs so far. Show them.
    else
    {
      ul.find("li").remove();
      jQuery.each(org.mo.sv.create.inputData["matched_svds"], function(i, val) {
        ul.append("<li><a href=\"/semantic_vernacular/show?uri=" 
          + encodeURIComponent(uris[val]) 
          + "\">" + val + "</a></li>");
      });
    }
  }
};

// Callback function to show values for a selected feature in the 
// "svd-create-feature-value" multiple select box.
org.mo.sv.create.getFeatureValuesCallback = function(response)
{
  var data = response["results"]["bindings"];
  var select = jQuery("select#svd-create-feature-value");
  select.children().remove();
  jQuery.each(data, function(i, val) {
    select.append("<option value=\"" + val["uri"]["value"] + "\">" 
      + val["label"]["value"] + "</option>");
  });
  // Dynamically set the height of the select box
  select.css("height", parseInt(select.find("option").length * 15));
};

// Callback function to show features in the "svd-create-feature" drop-down list.
org.mo.sv.create.getFeaturesCallback = function(response)
{
  var data = response["results"]["bindings"];
  var select = jQuery("select#svd-create-feature");
  // Remove the previously selected feature.
  select.find("option:selected").not(".svd-feature-select-default").remove();
  jQuery("option.svd-feature-select-default").attr("selected", true);
  // Add features returned from the query to the drop-down list .
  if (data.length != 0) {
    select.append("<option class=\"svd-feature-select-separator\" " 
      + "disabled>-------</option>");
    jQuery.each(data, function(i, val) {
      select.append("<option value=\"" + val["uri"]["value"] + "\">"
        + val["label"]["value"] + "</option>");
    });
  }
  // If the last <option> element in the drop-down list is the separator, remove
  // it.
  if (select.children().last().attr("class") == "svd-feature-select-separator")
    select.children().last().remove();
};