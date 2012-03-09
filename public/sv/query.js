/*
 * QueryNo:
 * 1 - list all the features which don't have dependent features.
 * 2 - list all sub features of a selected feature (e.g. color).
 * 3 - list all values of a selected feature.
 * 4 - list features that are dependent on the selected feature/value pair.
 * 5 - list possible vernaculars given a feature/value pair.
 * 6 - list possible species given a feature/value pair.
 * 7 - list all feature/value pairs given a vernacular.
 * 8 - list all feature/value pairs given a species.
 * 9 - list rdfs:seeAlso information of a given species.
 */


/*
 * Submit a HTTP request to the sparql proxy service to query the endpoint. 
 * The query results (json objects) are stored in three arrays.
 */
 //Modifications to make it ajaxy
query_labels=[];
query_features=[];
query_values=[];
query_urls=[];
boolean_query_ready=false; //not used
map_query_to_type=[]; //record the query to which queryType

save_queries=[]; //used with map_query_to_type to save values for update

//clears the state of everything - used after submitQUery completes in Interact.js
function clearStateInfo(){
	query_labels=[];
	query_features=[];
	query_values=[];
	query_urls=[];
	boolean_query_ready=false;
}


function submitQuery(queryNo) {
	var query = getQuery(queryNo);
	var endpoint = "http://aquarius.tw.rpi.edu:2024/sparql";
	var sparqlProxy = "http://logd.tw.rpi.edu/ws/sparqlproxy.php";
	var output = "exhibit"; // Options: xml, exhibit, sparql, gvds, csv, html
	var queryURL = sparqlProxy + "?" 
				   + "query=" + encodeURIComponent(query)
				   + "&service-uri=" + encodeURIComponent(endpoint)
				   + "&output=" + output;
	//input["features"] = ["has overall shape"];
	
	boolean_query_ready=false;
	map_query_to_type[queryURL]=queryNo;
	$.getJSON(queryURL, function(data) {
			query_labels=[];
			query_features=[];
			query_values=[];
			boolean_query_ready=true;
			var number=map_query_to_type[queryURL];
		$.each(data.items, function(i, object) {
			
		     
			query_labels.push(object.label);
			query_features.push(object.feature);
			query_values.push(object.value);
			query_urls.push(object.url);
			
			//alert(object.label+" "+object.feature+" "+object.value);
		});
		
		
		//alert(map_query_to_type[queryURL]);
		//alert(query_labels.length+" HUH "+query_features.length+" HUH "+query_values.length);
		save_queries[map_query_to_type[queryURL]]=query_labels;
		//alert(query_values);
		//if(map_query_to_type[queryURL]==6) alert(query_labels);
	});
}

/* 
 * Get user selections from the drop-down lists.
 */
 input=[];
 input["features"] = {};//["has overall shape"];
 input["values"] = {};//["stipitate agaric"];
 input["vernaculars"] = {};//["PineSpike"];
 input["species"] = ["Russula albida"];//, "Chroogomphus rutilus"];
 input["features"] = ["has color"];
	

 function getInput() {
	
	
	return input;
}

function setInput(ary_vals){
  input=ary_vals;
}
/*
 * Construct queries.
 */
function getQuery(queryNo) {
	var query = "";
	var input = getInput();
	query += getPrefixes();
	query += getHeader(queryNo);
	query += getBody(queryNo, input);
	query += getFilters(queryNo, input);
	query += getFooter();
	return query;
}

function getPrefixes() {
	var prefixes = "";
	var owl = "http://www.w3.org/2002/07/owl#";
	var rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";
	var rdfs = "http://www.w3.org/2000/01/rdf-schema#";
	var mushroom = "http://aquarius.tw.rpi.edu/ontology/mushroom.owl#";
	prefixes += "PREFIX owl: <" + owl + ">\n";
	prefixes += "PREFIX rdfs: <" + rdfs + ">\n";
	prefixes += "PREFIX rdf: <" + rdf + ">\n";
	prefixes += "PREFIX mushroom: <" + mushroom + ">\n";
	return prefixes;
}

function getHeader(queryNo) {
	var header = "SELECT DISTINCT ";
	if (queryNo == 7 || queryNo == 8)
		header += "?feature ?value\n";
	else if (queryNo == 9)
		header += "?url\n";
	else
		header += "?label\n";
	return header;
}

function getBody(queryNo, input) {
	var body = "WHERE { ";
	switch (queryNo)
	{
		case 1:
			body += "?feature rdfs:subPropertyOf mushroom:hasFeature .\n";
			body += "?feature rdfs:label ?label .\n"
			break;
		case 2:
			if (input["features"].length == 1) {
				body += "?parent rdfs:label \"" + input["features"][0] + "\"^^rdfs:Literal .\n";
				body += "?feature rdfs:subPropertyOf ?parent .\n";
				body += "?feature rdfs:label ?label .\n";
			}
			break;
		case 3:
			if (input["features"].length == 1) {
				body += "?feature rdfs:label \"" + input["features"][0] + "\"^^rdfs:Literal .\n";
				body += "?feature rdfs:range ?range .\n";
				body += "?range owl:equivalentClass ?class .\n";
				body += "?class owl:unionOf ?list .\n";
				body += "?list rdf:rest*/rdf:first ?member .\n";
				body += "?member rdfs:label ?label .\n";
			}
			break;
		case 4:
			if (input["features"].length == 1 && input["values"].length == 1) {
				body += "?feature rdfs:domain ?domain .\n";
				body += "?feature rdfs:label ?label .\n";
				body += "{ ?domain owl:intersectionOf ?list . } UNION\n";
				body += "{ ?domain owl:intersectionOf (mushroom:Fungus ?union) .\n";
				body += "?union owl:unionOf ?list . }\n";
				body += "?list rdf:rest*/rdf:first ?member .\n";
				body += "?member a owl:Restriction .\n";
				body += "?member owl:onProperty ?f .\n";
				body += "?f rdfs:label \"" + input["features"][0] + "\"^^rdfs:Literal .\n";
				body += "?member owl:someValuesFrom ?v .\n";
				body += "?v rdfs:label \""+ input["values"][0] + "\"^^rdfs:Literal .\n";
			}
			break;
		case 5:
			if (input["features"].length == 1 && input["values"].length == 1) {
				body += "?mushroom owl:equivalentClass ?class .\n";
				body += "?mushroom rdfs:label ?label .\n";
				body += "?class owl:intersectionOf ?list .\n";
				body += "{ ?list rdf:rest*/rdf:first ?member . } UNION\n";
				body += "{ ?list rdf:rest*/rdf:first ?m .\n";
				body += "?m owl:unionOf ?union .\n";
				body += "?union rdf:rest*/rdf:first ?member . }\n";
				body += "?member a owl:Restriction .\n";
				body += "?member owl:onProperty ?f .\n";
				body += "?f rdfs:label \"" + input["features"][0] + "\"^^rdfs:Literal .\n";
				body += "?member owl:someValuesFrom ?v .\n";
				body += "?v rdfs:label \""+ input["values"][0] + "\"^^rdfs:Literal .\n";
			}
			break;
		case 6:
			if (input["features"].length == 1 && input["values"].length == 1) {
				body += "{ ?mushroom owl:subClassOf ?class .\n";
				body += "?class owl:unionOf ?list .\n";
				body += "?list rdf:rest*/rdf:first ?member . } UNION\n";
				body += "{ ?mushroom rdfs:subClassOf ?member . }\n";
				body += "?mushroom rdfs:label ?label .\n";
				body += "?member a owl:Restriction .\n";
				body += "?member owl:onProperty ?f .\n";
				body += "?f rdfs:label \"" + input["features"][0] + "\"^^rdfs:Literal .\n";
				body += "?member owl:someValuesFrom ?v .\n";
				body += "?v rdfs:label \""+ input["values"][0] + "\"^^rdfs:Literal .\n";
			}
			break;
		case 7:
			if (input["vernaculars"].length == 1) {
				body += "?vern rdfs:label \"" + input["vernaculars"][0] + "\"^^rdfs:Literal .\n";
				body += "?vern owl:equivalentClass ?class .\n";
				body += "?class owl:intersectionOf ?list . \n";
				body += "{ ?list rdf:rest*/rdf:first ?member . } UNION\n";
				body += "{ ?list rdf:rest*/rdf:first ?m .\n";
				body += "?m owl:unionOf ?union .\n";
				body += "?union rdf:rest*/rdf:first ?member . }\n";
				body += "?member a owl:Restriction .\n";
				body += "?member owl:onProperty ?f .\n";
				body += "?f rdfs:label ?feature .\n";
				body += "?member owl:someValuesFrom ?v .\n";
				body += "?v rdfs:label ?value .\n";
			}
			break;
		case 8:
			if (input["species"].length == 1) {
				body += "?species rdfs:label \"" + input["species"][0] + "\"^^rdfs:Literal .\n";
				body += "{ ?species rdfs:subClassOf ?class .\n";
				body += "?class owl:unionOf ?list .\n";
				body += "?list rdf:rest*/rdf:first ?member . } UNION\n";
				body += "{ ?species rdfs:subClassOf ?member . }\n";
				body += "?member a owl:Restriction .\n";
				body += "?member owl:onProperty ?f .\n";
				body += "?f rdfs:label ?feature .\n";
				body += "?member owl:someValuesFrom ?v .\n";
				body += "?v rdfs:label ?value .\n";
			}
			break;
		case 9:
			if (input["species"].length == 1) {
				body += "?species rdfs:label \"" + input["species"][0] + "\"^^rdfs:Literal .\n";
				body += "?species rdfs:seeAlso ?url .\n";
			}
			break;
		default:
			alert("Unknown query number: " + queryNo + "!");
	}
	return body;	
}

function getFilters(queryNo, input) {
	var filters = "";
	switch (queryNo)
	{
		case 1:
			filters += "FILTER (!EXISTS { ?feature rdfs:domain ?domain . ?domain owl:intersectionOf ?intersection . })\n";
			filters += "FILTER (!EXISTS { ?feature rdfs:label \"has color\"^^rdfs:Literal . })\n";
			filters += "FILTER (!EXISTS { ?feature rdfs:label \"has status\"^^rdfs:Literal . })\n";
			filters += "FILTER (!EXISTS { ?feature rdfs:label \"has feature\"^^rdfs:Literal . })\n";
			break;
		case 2:
			filters += "FILTER (!EXISTS { ?feature rdfs:label \"" + input["features"][0] + "\"^^rdfs:Literal . })\n";
			break;
		case 3:
			break;
		case 4:
			break;
		case 5:
			for (var i = 0; i < input["vernaculars"].length; i++) {
				filters += "FILTER (!EXISTS { ?mushroom rdfs:label \"" + input["vernaculars"][i] + "\"^^rdfs:Literal . })\n";
			}
			break;
		case 6:
			for (var i = 0; i < input["species"].length; i++) {
				filters += "FILTER (!EXISTS { ?mushroom rdfs:label \"" + input["species"][i] + "\"^^rdfs:Literal . })\n";
			}
			break;
		case 7:
			break;
		case 8:
			break;
		case 9:
			break;
		default:
			alert("Unknown query number: " + queryNo + "!");
	}
	return filters;
}

function getFooter() {
	var footer = "";
	footer += "\n}";
	return footer;
}