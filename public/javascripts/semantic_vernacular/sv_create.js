/* Javascript helpers for the SVD "create" page.
/*
/******************************************************************************/

jQuery.noConflict();

window.onload = function()
{
  // If there is an URI passed, put it into postData.
  if (jQuery("input#svd-create-uri").val() != undefined)
    org.mo.sv.create.postData["svd"]["uri"] = 
      jQuery("input#svd-create-uri").val();

  // If there are base features passed, put them into baseFeatures.
  if (jQuery("ul#svd-feature-value-display").find("li").length > 0) {
    jQuery("ul#svd-feature-value-display")
      .find("div.svd-create-display-header").show();
    org.mo.sv.create.parseBaseFeatures();
  }

  // When the user enter something in the "svd-create-label" text box, put it
  // into postData.
  jQuery("input#svd-create-label").change(function() {
    org.mo.sv.create.postData["label"]["value"] = jQuery(this).val();
  });

  // Display all independent features in the "svd-create-feature" select box.
  org.mo.sv.submitQuery(
    org.mo.sv.create.queryIndependentFeatures(), 
    org.mo.sv.create.getFeaturesCallback);

  // Display all values for a selected feature in the "svd-feature-value" 
  // multiple select box.
  jQuery("select#svd-create-feature").change(function() {
    var selected = jQuery(this).find("option:selected");
    if (selected.length == 1) {
      var feature = selected.attr("id");
      org.mo.sv.submitQuery(
        org.mo.sv.create.queryFeatureValues(feature), 
        org.mo.sv.create.getFeatureValuesCallback);
    }
    // The user cannot select multiple features at one time.
    else {
      alert("You should select only one feature at a time!");
      selected.attr("selected", false);
      jQuery(this).find("option.svd-create-select-default")
        .attr("selected", true);
    }
  });

  // When the "svd-add-feature" button is clicked: store selected feature-value
  // pairs and matched SVDs to postData, display selected feature-value pairs
  // and matched SVDs. 
  jQuery("button#svd-add-feature")
    .click(org.mo.sv.create.addFeatureCallback);

  // When the "svd-clear-feature" button is clicked: reset the 
  // "svd-create-feature" select box, clear postData["features"] and 
  // postData["matched_svds"], and clear the display area.
  jQuery("button#svd-clear-feature")
    .click(org.mo.sv.create.clearFeatureCallback);

  // When the "svd-add-scientific-name" button is clicked: display the input and
  // put it into postData["scientific_names"].
  jQuery("button#svd-add-scientific-name")
    .click(org.mo.sv.create.addScientificNameCallback);

  // When the "svd-clear-scientific-name" button is clicked: clear the display
  // area and postData["scientific_names"].
  jQuery("button#svd-clear-scientific-name")
    .click(org.mo.sv.create.clearScientificNameCallback);

  // When the "svd-create-submit" button is clicked: send postData to backend 
  // to convert them to RDF, and then insert them into the triple store.
  jQuery("button#svd-create-submit").click(org.mo.sv.create.submitCallback);
};

// Callback function for clicking the "svd-create-submit" button.
org.mo.sv.create.submitCallback = function()
{
  // Label and definition must be filled for a new SVD creation.
  if (jQuery("input#svd-create-label").val() != undefined &&  
      org.mo.sv.create.postData["label"]["value"] == null)
    alert("\"Name\" must be filled!");
  // Definition must be filled for a new definition proposal.
  else if (org.mo.sv.create.postData["features"].length == 0)
    alert("\"Definition\" must be filled!");
  else {
    // When postData["svd"] has any SVD that is currently available, remind the
    // user his/her input of definition is not a new one.
    if (org.mo.sv.create.matchedSVDs[0] != "none")
      alert("Your input of definition has matched one or more current " + 
        "vernacular desctiptions in the database, please refine your input!");
    else {
      console.log(org.mo.sv.create.postData);
      //Post postData to backend to generate RDF.
      var post_url = "/semantic_vernacular/propose";
      var post_data = {"data": JSON.stringify(org.mo.sv.create.postData)};
      var post_callback = function(response) {
        console.log(response);
      if(response.message == "OK")
        alert("The new proposal has been submitted!");
      else
        alert(response.value);
      window.location.href = "/semantic_vernacular/show?uri="
        + encodeURIComponent(response.page_uri);
      };
      org.mo.sv.ajax(post_url, "POST", post_data, post_callback);
      //Clear postData.
      org.mo.sv.clearPostData();
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
  // Clear postData["scientific_names"].
  org.mo.sv.create.postData["scientific_names"] = [];
  //console.log(org.mo.sv.create.postData);
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
    jQuery.each(org.mo.sv.create.postData["scientific_names"], 
      function(i, val) {
        if (val["label"] == name) flag = true;
      });
    if (flag == true) {
      alert("You have already input this scientific name!");
      jQuery("input#svd-create-scientific-name").val("");
    }
    else {
      // Display the input.
      var ul = jQuery("ul#svd-scientific-name-display");
      ul.find("div.svd-create-display-header").show();
      ul.append("<li>" + name + "</li>");
      // Store the input into postData["scientific_names"].
      var obj = {"id": null, "uri": null, "label": name};
      org.mo.sv.create.postData["scientific_names"].push(obj);
      // Clear the "svd-create-scientific-name" input box.
      jQuery("input#svd-create-scientific-name").val("");
      //console.log(org.mo.sv.create.postData);
    }
  }
};

// Callback function for clicking the "svd-clear-feature" button.
org.mo.sv.create.clearFeatureCallback = function()
{
  // Reset the "svd-feature" select box to show all independent features.
  jQuery("select#svd-create-feature")
    .find("option").not(".svd-create-select-default").remove();
  jQuery("select#svd-create-feature-value")
    .find("option").not(".svd-create-select-default").remove();
  org.mo.sv.submitQuery(
    org.mo.sv.create.queryIndependentFeatures(), 
    org.mo.sv.create.getFeaturesCallback);
  // Clear postData["features"] and postData["matched_svds"].
  org.mo.sv.create.postData["features"] = [];
  org.mo.sv.create.matchedSVDs = [];
  // Clear the display area.
  var ul = jQuery("ul#svd-matched-svd-display");
  ul.find("li").remove();
  ul.find("div.svd-create-display-header").hide();
  ul = jQuery("ul#svd-feature-value-display");
  ul.find("li").remove()
  ul.find("div.svd-create-display-header").hide();
  //console.debug(org.mo.sv.create.postData);
};

// Callback function for clicking the "svd-add-feature" button.
org.mo.sv.create.addFeatureCallback = function()
{
  var feature = 
    jQuery("select#svd-create-feature").find("option:selected").attr("id");
  var feature_label = 
    jQuery("select#svd-create-feature").find("option:selected").val();
  var values = [];
  var value_labels = [];
  jQuery("select#svd-create-feature-value")
    .find("option:selected").each(function() {
      values.push(jQuery(this).attr("id"));
      value_labels.push("<span class=\"svd-show-feature-value\" " 
        + "id=\"" + jQuery(this).attr("id") + "\">" + jQuery(this).val() 
        + "</span>");
    });
  if (feature == "" || values.length == 0) 
    alert("No value selected!");
  else
  {
    // Put selected feature-value pairs to postData["features"].
    var obj = {"feature": feature, "values": values};
    org.mo.sv.create.postData["features"].push(obj);
    // Display selected feature-value pairs in the display area.
    var ul = jQuery("ul#svd-feature-value-display");
    if (ul.find("div.svd-create-display-header").css("display") == "none")
      ul.find("div.svd-create-display-header").show();
    ul.append("<li id=\"" + feature + "\" title=\"" + feature_label + "\">" 
      + feature_label + ": " + value_labels.join(" <i>or</i> ") 
      + " <button type=\"button\" class=\"svd-remove-feature-value\">" 
      + "<u>remove</u></button></li>");
    // When the "svd-remove-feature-value" button is clicked: remove the 
    // feature-value pair from the display area, delete that pair from the
    // postData, reset matched SVDs, and reset features available in the
    // "svd-create-feature" select box.
    jQuery("button.svd-remove-feature-value")
      .unbind("click").click(org.mo.sv.create.removeFeatureValueCallback);
    // Display available SVDs based on feature selections in the display area.
    org.mo.sv.create.getMatchedSVDs(
      org.mo.sv.create.postData["features"]);
    // Add features dependent on the previously selected feature-value pairs in 
    // the "svd-feature" select box.
    org.mo.sv.submitQuery(
      org.mo.sv.create.queryDependentFeatures(feature, values), 
      org.mo.sv.create.getFeaturesCallback);
    // Clear "svd-feature-value" multiple select box. 
    jQuery("select#svd-create-feature-value")
      .find("option").not(".svd-create-select-default").remove();
  }
  //console.log(org.mo.sv.create.postData);
};

// Callback function for clicking the "svd-remove-feature-value" button.
org.mo.sv.create.removeFeatureValueCallback = function()
{
  // Find out which feature-value pair the user wanted to remove.
  var feature = jQuery(this).parent().attr("id");
  var feature_label = jQuery(this).parent().attr("title");
  var obj = {};
  jQuery.each(org.mo.sv.create.postData["features"], function(i, val) {
    if (val["feature"] == feature)
      obj = val;
  });
  // Remove the feature-value pair from postData.
  org.mo.sv.create.postData["features"] = 
    jQuery.grep(org.mo.sv.create.postData["features"], function(value) {
      return value != obj;
  });
  // Remove the feature-value pair from the display list.
  jQuery(this).parent().remove();
  if (jQuery("ul#svd-feature-value-display").find("li").length == 0)
    jQuery("ul#svd-feature-value-display .svd-create-display-header")
      .css("display", "none");
  // Reset the matched SVD list.
  org.mo.sv.create.getMatchedSVDs(
    org.mo.sv.create.postData["features"]);
  // Reset the "svd-create-feature" select box: remove the dependent
  // features of this feature-value pair and add this feature back in the 
  // select box.
  obj["feature_label"] = feature_label
  org.mo.sv.create.resetFeatures(obj);
}

// Display matched SVDs based on the current postData.
org.mo.sv.create.getMatchedSVDs = function(features)
{
  var ul = jQuery("ul#svd-matched-svd-display");
  if (ul.find("div.svd-create-display-header").css("display") == "none")
    ul.find("div.svd-create-display-header").show();
  ul.find("li").remove();
  if (features.length == 0)
    ul.find("div.svd-create-display-header").css("display", "none");
  org.mo.sv.create.matchedSVDs = [];
  jQuery.each(features, function(i, val) {
    org.mo.sv.submitQuery(
      org.mo.sv.create.querySVDForFeatureValue(val["feature"], val["values"]), 
      org.mo.sv.create.getMatchedSVDsCallback);
  });  
};

// Callback function to display matched SVDs based on the current postData.
org.mo.sv.create.getMatchedSVDsCallback = function(response)
{
  var uris = {};
  var labels = [];
  jQuery.each(response["results"]["bindings"], function(i, val) {
    var key = val["label"]["value"];
    uris[key] = val["uri"]["value"];
    labels.push(val["label"]["value"]);
  });
  if (labels.length == 0)
    org.mo.sv.create.matchedSVDs[0] = "none";
  // If this is the first feature-value pair added, just show whatever SVD that 
  // mathch that pair.
  var ul = jQuery("ul#svd-matched-svd-display");
  if (org.mo.sv.create.matchedSVDs.length == 0) {
    jQuery.each(labels, function(i, val) {
      org.mo.sv.create.matchedSVDs.push(val);
      ul.append("<li><a href=\"/semantic_vernacular/show?uri=" 
        + encodeURIComponent(uris[val]) + "\" target=\"_blank\">" 
         + val + "</a></li>");
    });
  }
  // If previously added feature-value pairs didn't match any SVD, no SVD will 
  // show for the newly added pair.
  else if (org.mo.sv.create.matchedSVDs[0] == "none") {
    ul.find("li").remove();
    ul.append("<li>None</li>");
  }
  // If previously added feature-value pairs have matched SVDs, show the 
  // intersection of the previously matched SVDs and the SVDs matching the new 
  // pair.
  else {
    // Remove any SVD in postData["matched_svds"] that doesn't match the newly 
    // added feature-value pair.
    org.mo.sv.create.matchedSVDs = 
      jQuery.map(org.mo.sv.create.matchedSVDs, function(ele) {
        if (jQuery.inArray(ele, labels) == -1) {
          org.mo.sv.create.matchedSVDs = jQuery.grep(
            org.mo.sv.create.matchedSVDs, function(value) {
              return value != ele;
          });
          return null;
        }
        else 
          return ele;
    });
    // If nothing is left in postData["matched_svds"], it means no SVD match 
    // the new pair.
    if (org.mo.sv.create.matchedSVDs.length == 0) {
      org.mo.sv.create.matchedSVDs[0] = "none";
      ul.find("li").remove();
      ul.append("<li>None</li>");
    }
    // The SVDs left are the ones that match all the added pairs so far. Show 
    // them.
    else
    {
      ul.find("li").remove();
      jQuery.each(org.mo.sv.create.matchedSVDs, function(i, val) {
        ul.append("<li><a href=\"/semantic_vernacular/show?uri=" 
          + encodeURIComponent(uris[val]) + "\" target=\"_blank\">" 
          + val + "</a></li>");
      });
    }
  }
};

// Reset the "svd-create-feature" select box after the user removes a
// feature-value pair.
org.mo.sv.create.resetFeatures = function(feature_obj)
{
  var select = jQuery("select#svd-create-feature");
  org.mo.sv.submitQuery(
    org.mo.sv.create.queryDependentFeatures(
      feature_obj["feature"], feature_obj["values"]), 
    function(response) {
      // Remove the dependent features.
      var data = response["results"]["bindings"];
      jQuery.each(data, function(i, val) {
        select.find("option[id=\'" + val["uri"]["value"] + "\']").remove();
      });
      // Push the removed feature back in the select box.
      select.append("<option id=\"" + feature_obj["feature"] + "\" "
        + "value=\"" + feature_obj["feature_label"] + "\">" +
        feature_obj["feature_label"] + "</option>");
    });
};

// Callback function to show values for a selected feature in the 
// "svd-create-feature-value" multiple select box.
org.mo.sv.create.getFeatureValuesCallback = function(response)
{
  var data = response["results"]["bindings"];
  var select = jQuery("select#svd-create-feature-value");
  select.find("option").not(".svd-create-select-default").remove();
  jQuery.each(data, function(i, val) {
    select.append("<option id=\"" + val["uri"]["value"] + "\" " 
      + "value=\"" + val["label"]["value"] + "\">" + val["label"]["value"] 
      + "</option>");
  });
};

// Callback function to show features in the "svd-create-feature" select box.
org.mo.sv.create.getFeaturesCallback = function(response)
{
  // Remove the previously selected feature.
  var select = jQuery("select#svd-create-feature");
  select.find("option:selected").not(".svd-create-select-default").remove();
  select.find("option.svd-create-select-default").attr("selected", true);
  // An array to hold currently input features. Don't show any features in this
  // list in the "svd-create-feature" select box. Do show the ones that depend
  // on the features in this list.
  var current_feature_list = [];
  jQuery.each(org.mo.sv.create.postData["features"], function(i, val) {
      current_feature_list.push(val["feature"]);
  });
  // If currently there are entries in postData["features"], don't show them in
  // the "svd-create-feature" select box, but show their dependent features.
  // if (org.mo.sv.create.baseFeatures.length > 0) {
  //   jQuery.each(org.mo.sv.create.baseFeatures, function(i, val) {
  //     current_feature_list.push(val["feature"]);
  //     org.mo.sv.submitQuery(
  //       org.mo.sv.create.queryDependentFeatures(val["feature"], val["values"]),
  //       function(res) {
  //         var data = res["results"]["bindings"];
  //         jQuery.each(data, function(i, val) {
  //           if (val != {} && 
  //             jQuery.inArray(val["uri"]["value"], current_feature_list) == -1)
  //               select.append("<option value=\"" + val["uri"]["value"] + "\">"
  //               + val["label"]["value"] + "</option>");
  //         });
  //         org.mo.sv.create.baseFeatures = [];
  //         org.mo.sv.create.getMatchedSVDs(
  //           org.mo.sv.create.postData["features"]);
  //       }
  //     );
  //   });
  // }
  // Add features returned from the query to the select box.
  var data = response["results"]["bindings"];
  if (data.length > 0) {
    jQuery.each(data, function(i, val) {
      if (jQuery.inArray(val["uri"]["value"], current_feature_list) == -1)
        select.append("<option id=\"" + val["uri"]["value"] + "\" " 
          + "value=\"" + val["label"]["value"] + "\">" + val["label"]["value"] 
          + "</option>");
    });
  }
};

// Function to parse the passed base features and put them in postData.
org.mo.sv.create.parseBaseFeatures = function()
{
  var ul = jQuery("ul#svd-feature-value-display");
  ul.find("li").each(function(i, ele) {
    var feature = jQuery(ele).attr("id");
    var values = [];
    jQuery(ele).find("span.svd-show-feature-value").each(function(i, ele) {
      values.push(jQuery(ele).attr("id"));
    });
    jQuery(ele).append(
      " <button type=\"button\" class=\"svd-remove-feature-value\">" 
      + "<u>remove</u></button></li>");
    jQuery("button.svd-remove-feature-value")
      .unbind("click").click(org.mo.sv.create.removeFeatureValueCallback);
    //org.mo.sv.create.baseFeatures.push({"feature": feature, "values": values});
    org.mo.sv.create.postData["features"]
      .push({"feature": feature, "values": values});
  });
  jQuery.each(org.mo.sv.create.postData["features"], function(i, val) {
    org.mo.sv.submitQuery(
      org.mo.sv.create.queryDependentFeatures(val["feature"], val["values"]),
      org.mo.sv.create.getFeaturesCallback);
  });
  org.mo.sv.create.getMatchedSVDs(
      org.mo.sv.create.postData["features"]);
}