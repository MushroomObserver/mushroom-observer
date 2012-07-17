# encoding: utf-8
#
#  = Semantic Vernacular Data Source
#
#  This class describes the abstract data model for the semantic vernacular
#  module. Subclasses should override some of the methods to implement 
#  corresponding functionalities. Data are retrieved directly through a triple 
#  store.
#
#  == Class Methods
#  === Public
#  index::    						List all instances.
#  === Private
#  query:: 								Submit a query to the triple store and get responses.
#  query_all:: 						Build a query to get all instances.
#
#  == Instance Methods
#  ==== Public
#  to_s::           			Returns the lable for a given instance.
#  get_label::						Returns the lable for a given instance.
#  
#  ==== Private
#  query_label:: 					Build a query to get the lable for a given instance.
#
################################################################################

require "sparql/client"

class SemanticVernacularDataSource

	def self.ask_max_ID(type)
		query(query_max_ID(type))
	end

	def self.id_to_uri(id, type)
		uri = SVF_NAMESPACE + 
		case type
		when "SemanticVernacularDescription" then "SVD"
		when "VernacularDefinition" then "VD"
		when "ScientificName" then "SN"
		when "VernacularLabel" then "VL"
		when "User" then "User"
		end
		uri << id.to_s
	end

	def self.insert_label(svd, label, user)
		update(insert_update(label_rdf(svd, label, user)))
	end

	def self.delete_label()
	end

	def self.insert_definition(svd, definition, features, user)
		update(insert_update(definition_rdf(svd, definition, features, user)))
	end

	def self.delete_definition()
	end

	def self.insert_scientific_names(svd, scientific_names)
		update(insert_update(scientific_names_rdf(svd, scientific_names)))
	end

	def self.scientific_names()
	end

	def self.insert_svd(svd)
		update(insert_update(svd_rdf(svd)))
	end

	def self.delete_svd()
	end
	

	def self.test(svd)
		svd_rdf(svd)
	end

	private
	
	QUERY_ENDPOINT = "http://aquarius.tw.rpi.edu:2024/sparql"
	UPDATE_ENDPOINT = "http://128.128.170.15:3030/svf/update"
	#QUERY_ENDPOINT = "http://leo.tw.rpi.edu:2058/svf/sparql"
	#UPDATE_ENDPOINT = "http://leo.tw.rpi.edu:2058/svf/update"
	SVF_NAMESPACE = "http://mushroomobserver.org/svf.owl#"

	# Retrun: array of hashes
	# [{"key_1" => "value_1"}, {"key_2" => "value_2"}, ...]
	# def self.query(query)
	# 	sparql = SPARQL::Client.new(QUERY_ENDPOINT)
 	# 	response = sparql.query(query).to_a # RDF::Query::Solution
 	# end

  def self.query(query)
		url = URI(QUERY_ENDPOINT)
		params = { :query => query, :output => :json }
		url.query = URI.encode_www_form(params)
		response = Net::HTTP.get_response(url)
		if response.is_a?(Net::HTTPSuccess)
			ActiveSupport::JSON.decode(response.body)["results"]["bindings"]
		else 
			response.value
		end
	end

  def self.update(query)
		Net::HTTP.post_form(URI(UPDATE_ENDPOINT), "update" => query)
  end

  # Prefix for all SPARQL queries.
	QUERY_PREFIX = 
		%(PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			PREFIX svf: <#{SVF_NAMESPACE}>\n)

	def self.query_max_ID(type)
		query = QUERY_PREFIX + %(SELECT ?id WHERE {)
		case type
		when "SemanticVernacularDescription", "VernacularDefinition", 
			"ScientificName"
			query << %(?uri rdfs:subClassOf svf:#{type} . )
		when "VernacularLabel", "User"
			query << %(?uri a svf:#{type} . )
		end
		query << "?uri svf:hasID ?id } ORDER BY DESC (?id) LIMIT 1"
	end

	def self.insert_update(rdf)
		QUERY_PREFIX + %(INSERT DATA { #{rdf} }) 
	end

	def self.delete_update(rdf)
		QUERY_PREFIX + %(DELETE DATA { #{rdf} })
	end

	def self.label_rdf(svd, label, user)
		%(<#{svd["uri"]}> 
				rdfs:subClassOf
					#{has_object_value_restriction_rdf(
						SVF_NAMESPACE + "hasLabel", label["uri"])} . 
			<#{label["uri"]}>
				a owl:NamedIndividual, svf:VernacularLabel;
				rdfs:label "#{label["value"]}"^^rdfs:Literal;
				svf:hasID "#{label["id"]}"^^xsd:positiveInteger;
				svf:isDefault "#{label["is_default"]}"^^xsd:boolean;
				svf:proposedAt "#{Time.now.strftime("%FT%T%:z")}"^^xsd:dateTime;
				svf:proposedBy <#{user["uri"]}> . )
	end

	def self.definition_rdf(svd, definition, features, user)
		rdf = 
			%(<#{svd["uri"]}> 
					rdfs:subClassOf
						#{some_object_values_from_restriction_rdf(
							SVF_NAMESPACE + "hasDefinition", definition["uri"])} .
					<#{definition["uri"]}>
						a owl:class;
						rdfs:subClassOf svf:VernacularDefinition;
						rdfs:subClassOf
							#{has_object_value_restriction_rdf(
								SVF_NAMESPACE + "proposedBy", user["uri"])};
						rdfs:subClassOf
							#{has_datatype_value_restriction_rdf(
								SVF_NAMESPACE + "proposedAt", 
								Time.now.strftime("%FT%T%:z"), 
								"xsd:dateTime")};
						rdfs:subClassOf
							#{has_datatype_value_restriction_rdf(
								SVF_NAMESPACE + "isDefault", definition["is_default"], "xsd:boolean")};
						svf:hasID "#{definition["id"]}"^^xsd:positiveInteger;
						#{features_rdf(features)} . )			
	end

	def self.features_rdf(features)
		rdf = %(owl:equivalentClass
							[ a owl:class;
							owl:intersectionOf \(svf:Fungus )
		features.each do |feature|
			if feature["values"].length > 1
				rdf << %([ a owl:class;
									 owl:unionOf \()
				feature["values"].each do |value|
					rdf << some_object_values_from_restriction_rdf(
						feature["feature"], value)
				end
				rdf << %(\)])
			end
			if feature["values"].length == 1
				rdf << some_object_values_from_restriction_rdf(
					feature["feature"], feature["values"][0])
			end
		end
		rdf << %(\)])
	end

	def self.has_object_value_restriction_rdf(property, value)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:hasValue <#{value}> ])
	end

	def self.has_datatype_value_restriction_rdf(property, value, datatype)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:hasValue "#{value}"^^#{datatype} ])
	end

	def self.some_object_values_from_restriction_rdf(property, value)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:someValuesFrom <#{value}> ])
	end

	def self.scientific_names_rdf(svd, scientific_names)
		rdf = %()
		scientific_names.each do |scientific_name|
			rdf << 
				%(<#{svd["uri"]}>
						rdfs:subClassOf
							#{some_object_values_from_restriction_rdf(
								SVF_NAMESPACE + "hasAssociatedScientificName", 
								scientific_name["uri"])} . 
					<#{scientific_name["uri"]}>
						rdfs:subClassOf svf:ScientificName;
						rdfs:label "#{scientific_name["label"]}"^^rdfs:Literal;
						svf:hasID "#{scientific_name["id"]}"^^xsd:positiveInteger . )
		end
		return rdf
	end

	def self.svd_rdf(svd)
		%(<#{svd["uri"]}>
				a owl:Class;
				rdfs:subClassOf svf:SemanticVernacularDescription;
				svf:hasID "#{svd["id"]}"^^xsd:positiveInteger . )
	end

end