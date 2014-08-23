/* Javascript helpers for the semantic vernacular module.
/*
/******************************************************************************/

jQuery.noConflict();

// Namespaces.
if (window.org == undefined || typeof(org) != "object") 
  org = {};
if (org.mo == undefined || typeof(org.mo) != "object") 
  org.mo = {};
if (org.mo.sv == undefined || typeof(org.mo.sv) != "object") 
  org.mo.sv = {};
if (org.mo.sv.show == undefined || typeof(org.mo.sv.show) != "object") 
  org.mo.sv.show = {};
if (org.mo.sv.create == undefined || typeof(org.mo.sv.create) != "object") 
  org.mo.sv.create = {};

// Global variables.
// The RPI triple store endpoint url.
// org.mo.sv.endpoint = "http://leo.tw.rpi.edu:2058/svf/sparql";
// The MBL triple store endpoint url.
org.mo.sv.endpoint = "http://128.128.170.15:3000/svf/sparql";
// SVF graph URI.
org.mo.sv.SVFGraph = "http://mushroomobserver.org/svf.owl";
// SVF ontology namespace.
org.mo.sv.SVFNamespace = org.mo.sv.SVFGraph + "#";
// A global object to hold all the post data for creating a new SVD instance.
org.mo.sv.create.postData = {
  "svd": {},
  "label": {},
  "description": {},
  "features": [], 
  "scientific_names": [],
  "user": {
    // Use this test user for now.
    "uri": "http://mushroomobserver.org/svf.owl#SV1091"
  }
};
// A global array to hold matched SVDs for any input features.
org.mo.sv.create.matchedSVDs = [];
// A global array to hold passed base features.
org.mo.sv.create.baseFeatures = [];

// Empty postData.
org.mo.sv.clearPostData = function()
{
  org.mo.sv.create.postData = {
    "svd": {},
    "label": {},
    "description": {},
    "features": [], 
    "scientific_names": [],
    "user": {
      "uri": "http://mushroomobserver.org/svf.owl#SV1091"
    }
  };
};

// Submit a SPARQL query to the endpoint via the RPI SparqlProxy service.
org.mo.sv.submitQuery = function(query, callback, output)
{
  if (typeof output == "undefined")
    output = "json";
  var url = org.mo.sv.endpoint + "?" 
            + "query=" + encodeURIComponent(query)
            + "&output=" + encodeURIComponent(output);
  org.mo.sv.ajax(url, "GET", "", callback);
};

// Ajax function.
org.mo.sv.ajax = function(url, method, data, callback)
{
  if (jQuery.browser.msie && 
      parseInt(jQuery.browser.version, 10) >= 7 && window.XDomainRequest) {
    // Use Microsoft XDR
    var xdr = new XDomainRequest();
    xdr.open(method, url);
    xdr.onload = function () {
      callback(xdr.responseText);
    };
    xdr.send(data);
  } 
  else
    jQuery.ajax({
      url: url,
      type: method,
      data: data,
      dataType: "json",
      success: callback,
      failure: function(msg) {
        alert(msg);
      }
    });
};

// Build a SPARQL query to ask for the existence of an URI.
org.mo.sv.askURI = function(uri)
{
  var query = org.mo.sv.getQueryPrefix();
  query += "ASK { <" + uri + "> ?p ?o }";
  return query;
};

// Build a SPARQL query to ask for the existence of a label.
org.mo.sv.askLabel = function(label)
{
  var query = org.mo.sv.getQueryPrefix();
  query += "ASK { ?s rdfs:label \"" + label + "\"^^rdfs:Literal }";
  return query;
};

// Build a SPARQL query to get the URI given its label.
org.mo.sv.getURI = function(label)
{
  var query = org.mo.sv.getQueryPrefix();
  query += "SELECT ?uri\n";
  query += "FROM <" + org.mo.sv.SVFGraph + ">\n";
  query += "WHERE { ?uri rdfs:label \"" + label + "\"^^rdfs:Literal }";
  return query;
};

// Build a SPARQL query to get features dependent on selected feature-value 
// pairs.
org.mo.sv.create.queryDependentFeatures = function(feature, values)
{
  var query = org.mo.sv.getQueryPrefix();
  query += "SELECT DISTINCT ?uri ?label\n";
  query += "FROM <" + org.mo.sv.SVFGraph + ">\n";
  query += "WHERE {\n";
  query += "?uri rdfs:subPropertyOf+ svf:hasFungalFeature .\n";
  query += "?uri rdfs:label ?label .\n";
  query += "?uri rdfs:domain ?c1 .\n";
  query += "?c1 owl:intersectionOf ?c2 .\n";
  query += "{ ?c2 rdf:rest*/rdf:first ?c3 } UNION "
  query += "{ ?c2 rdf:rest*/rdf:first ?c4 . ";
  query += "?c4 owl:unionOf ?c5 . ";
  query += "?c5 rdf:rest*/rdf:first ?c3 . }\n";
  var arr = [];
  jQuery.each(values, function(i, val) {
    var str = "{ ?c3 owl:onProperty <" + feature + "> . ";
    str += "?c3 owl:someValuesFrom <" + val + "> . }";
    arr.push(str);
  });
  query += arr.join(" UNION ");
  query += "}";
  return query;
};

// Build a SPARQL query to get matched SVDs for selected feature-value pairs.
org.mo.sv.create.querySVDForFeatureValue = function(feature, values)
{
  var query = org.mo.sv.getQueryPrefix();
  query += "SELECT DISTINCT ?uri ?name\n";
  query += "FROM <" + org.mo.sv.SVFGraph + ">\n";
  query += "WHERE {\n";
  query += "?uri rdfs:subClassOf svf:SemanticVernacularDescription .\n";
  query += "OPTIONAL { ?uri rdfs:subClassOf ?c1 .\n";
  query += "?c1 owl:onProperty svf:hasSVDName .\n";
  query += "?c1 owl:hasValue ?vl .\n";
  query += "?vl rdfs:label ?name . }\n";
  query += "?uri rdfs:subClassOf ?c2 .\n";
  query += "{ ?c2 owl:onProperty svf:hasDefinition . } UNION ";
  query += "{ ?c2 owl:onProperty svf:hasDescription . }\n";
  query += "?c2 owl:someValuesFrom ?desc .\n";
  query += "?desc owl:equivalentClass ?c3 .\n";
  query += "?c3 owl:intersectionOf ?c4 .\n"; 
  query += "{ ?c4 rdf:rest*/rdf:first ?c5 . } UNION ";
  query += "{ ?c4 rdf:rest*/rdf:first ?c6 . ";
  query += "?c6 owl:unionOf ?c7 . ";
  query += "?c7 rdf:rest*/rdf:first ?c5 . }\n";
  var arr = [];
  jQuery.each(values, function(i, val) {
    var str = "{ ?c5 owl:onProperty <" + feature + "> . ";
    str += "?c5 owl:someValuesFrom <" + val + "> . }";
    arr.push(str);
  });
  query += arr.join(" UNION ");
  query += "}";
  return query;
};

// Build a SPARQL query to get values for a selected feature.
org.mo.sv.create.queryFeatureValues = function(feature)
{
  var query = org.mo.sv.getQueryPrefix();
  query += "SELECT DISTINCT ?uri ?label\n";
  query += "FROM <" + org.mo.sv.SVFGraph + ">\n";
  query += "WHERE {\n";
  query += "<" + feature + "> rdfs:range ?r .\n";
  query += "?r owl:equivalentClass ?c .\n";
  query += "?c owl:unionOf ?u .\n";
  query += "?u rdf:rest*/rdf:first ?c3 .\n";
  query += "?c4 rdfs:subClassOf* ?c3 .\n";
  query += "?c4 owl:equivalentClass* ?uri .\n";
  query += "?uri rdfs:label ?label . }";
  return query;
};

// Build a SPARQL query to get all independent features.
org.mo.sv.create.queryIndependentFeatures = function()
{
  var query = org.mo.sv.getQueryPrefix();
  query += "SELECT DISTINCT ?uri ?label\n";
  query += "FROM <" + org.mo.sv.SVFGraph + ">\n";
  query += "WHERE {\n";
  query += "?uri rdfs:subPropertyOf+ svf:hasFungalFeature .\n";
  query += "?uri rdfs:label ?label .\n";
  query += "FILTER (!EXISTS ";
  query += "{ ?uri rdfs:domain ?domain . ";
  query += "?domain owl:intersectionOf ?c . })\n";
  query += "FILTER (!EXISTS ";
  query += "{ ?uri rdfs:label \"has color\"^^rdfs:Literal . })\n";
  query += "FILTER (!EXISTS ";
  query += "{ ?uri rdfs:label \"has status\"^^rdfs:Literal . })}";
  return query;
};

// Build a SPARQL query to get annotations of a given feature value.
org.mo.sv.show.queryFeatureValueAnnotation = function(uri)
{
  var query = org.mo.sv.getQueryPrefix();
  query += "SELECT DISTINCT ?label ?description ?reference ?picLink\n";
  query += "FROM <" + org.mo.sv.SVFGraph + ">\n";
  query += "WHERE {\n";
  query += "<" + uri + "> rdfs:subClassOf+ svf:FungalFeatureValuePartition .\n";
  query += "<" + uri + "> owl:equivalentClass*/rdfs:label ?label .\n";
  query += "OPTIONAL { { <" + uri + "> dcterms:description ?description }";
  query += " UNION ";
  query += "{ <" + uri + "> owl:equivalentClass*/obo:IAO_0000115 ?description } . }\n";
  query += "OPTIONAL { <" + uri + "> dcterms:references ?r . ";
  query += "?r rdfs:label ?reference . }\n";
  query += "OPTIONAL { <" + uri + "> svf:hasPictureURL ?picLink . }}";
  return query;
}

// Get all query prefixes.
org.mo.sv.getQueryPrefix = function()
{
  var prefix = "PREFIX owl: <http://www.w3.org/2002/07/owl#>\n";
  prefix += "PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>\n";
  prefix += "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>\n";
  prefix += "PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>\n";
  prefix += "PREFIX obo: <http://purl.obolibrary.org/obo/>\n";
  prefix += "PREFIX dcterms: <http://purl.org/dc/terms/>\n";
  prefix += "PREFIX svf: <" + org.mo.sv.SVFNamespace + ">\n";
  return prefix;
};