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
			when "VernacularFeatureDescription" then "VFD"
			when "ScientificName" then "SN"
			when "VernacularLabel" then "VL"
			when "User" then "U"
		end
		uri << id.to_s
	end

	def self.insert_label(svd, label, user)
		update(insert_update(insert_label_rdf(svd, label, user)))
	end

	def self.delete_label(label)
		update(delete_update(delete_label_rdf(label)))
	end

	def self.accept_label(label)
		update(insert_delete_update(accept_label_rdf(label)))
	end

	def self.insert_description(svd, description, features, user)
		update(
			insert_update(insert_description_rdf(svd, description, features, user)))
	end

	def self.delete_description(description)
		update(delete_update(delete_description_rdf(description)))
	end

	def self.insert_scientific_names(svd, scientific_names)
		update(insert_update(insert_scientific_names_rdf(svd, scientific_names)))
	end

	def self.delete_scientific_name(scientific_name)
		update(delete_update(delete_scientific_name_rdf(scientific_name)))
	end

	def self.insert_svd(svd)
		update(insert_update(insert_svd_rdf(svd)))
	end

	def self.delete_svd(svd)
		update(delete_update(delete_svd_rdf(svd)))
	end

	private
	
	QUERY_ENDPOINT = "http://128.128.170.15:3030/svf/sparql"
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
		when "SemanticVernacularDescription", "VernacularFeatureDescription", 
			"ScientificName"
			query << %(?uri rdfs:subClassOf svf:#{type} . )
		when "VernacularLabel", "User"
			query << %(?uri a svf:#{type} . )
		end
		query << "?uri svf:hasID ?id } ORDER BY DESC (?id) LIMIT 1"
	end

	def self.insert_update(insert_rdf)
		QUERY_PREFIX + insert_rdf 
	end

	def self.delete_update(delete_rdf)
		QUERY_PREFIX + delete_rdf
	end

	def self.insert_delete_update(insert_delete_rdf)
		QUERY_PREFIX + insert_delete_rdf
	end

	def self.insert_label_rdf(svd, label, user)
		%(INSERT DATA {
				<#{svd["uri"]}> 
					rdfs:subClassOf
						#{insert_has_object_value_restriction_rdf(
							SVF_NAMESPACE + "hasLabel", label["uri"])} . 
				<#{label["uri"]}>
					a owl:NamedIndividual, svf:VernacularLabel;
					rdfs:label "#{label["value"]}"^^rdfs:Literal;
					svf:hasID "#{label["id"]}"^^xsd:positiveInteger;
					svf:isName "#{label["is_name"]}"^^xsd:boolean;
					svf:proposedAt "#{Time.now.strftime("%FT%T%:z")}"^^xsd:dateTime;
					svf:proposedBy <#{user["uri"]}> . 
			})
	end

	def self.delete_label_rdf(label)
		%(DELETE WHERE {
				?svd rdfs:subClassOf ?c .
				?c owl:hasValue <#{label}> .
				?c ?p1 ?o1 .
				<#{label}> ?p2 ?o2 . 
			})
	end

	def accept_label_rdf(label)
		%()
	end

	def self.insert_description_rdf(svd, description, features, user)
		%(INSERT DATA {
				<#{svd["uri"]}> 
					rdfs:subClassOf
						#{insert_some_object_values_from_restriction_rdf(
							SVF_NAMESPACE + "hasDescription", description["uri"])} .
				<#{description["uri"]}>
					a owl:class;
					rdfs:subClassOf svf:VernacularFeatureDescription;
					rdfs:subClassOf
						#{insert_has_object_value_restriction_rdf(
							SVF_NAMESPACE + "proposedBy", user["uri"])};
					rdfs:subClassOf
						#{insert_has_datatype_value_restriction_rdf(
							SVF_NAMESPACE + "proposedAt", 
							Time.now.strftime("%FT%T%:z"), 
							"xsd:dateTime")};
					rdfs:subClassOf
						#{insert_has_datatype_value_restriction_rdf(
							SVF_NAMESPACE + "isDefinition",
							description["is_definition"], "xsd:boolean")};
					svf:hasID "#{description["id"]}"^^xsd:positiveInteger;
					#{insert_features_rdf(features)} . 
			})			
	end

	def self.delete_description_rdf(description)
		%(DELETE {
				?svd rdfs:subClassOf ?c . 
				?c ?p1 ?o1 . 
				<#{description}> ?p2 ?o2 .
				?o3 ?p4 ?o4 .
				?list ?p6 ?o6 .
				?z rdf:first ?head .
				?z rdf:rest ?tail .
				?head ?p7 ?o7 .
			}
			WHERE {
				?svd rdfs:subClassOf ?c .
				?c owl:someValuesFrom <#{description}> .
				?c ?p1 ?o1 .
				<#{description}> ?p2 ?o2 .
				<#{description}> ?p3 ?o3 .
				?o3 ?p4 ?o4 .
				<#{description}> owl:equivalentClass ?o5 .
				?o5 owl:intersectionOf ?list .
				?list ?p6 ?o6 .
				?list rdf:rest* ?z .
				?z rdf:first ?head .
				?head ?p7 ?o7 .
				?z rdf:rest ?tail .
				FILTER isBlank(?o3)
			})
	end

	def self.insert_scientific_names_rdf(svd, scientific_names)
		rdf = %(INSERT DATA {)
		scientific_names.each do |scientific_name|
			rdf << 
				%(<#{svd["uri"]}>
						rdfs:subClassOf
							#{insert_some_object_values_from_restriction_rdf(
								SVF_NAMESPACE + "hasAssociatedScientificName", 
								scientific_name["uri"])} . 
					<#{scientific_name["uri"]}>
						rdfs:subClassOf svf:ScientificName;
						rdfs:label "#{scientific_name["label"]}"^^rdfs:Literal;
						svf:hasID "#{scientific_name["id"]}"^^xsd:positiveInteger . )
		end
		rdf << %(})
		return rdf
	end

	def self.delete_scientific_name_rdf(scientific_name)
		%(DELETE WHERE {
				?svd rdfs:subClassOf ?c . 
				?c owl:someValuesFrom <#{scientific_name}> .
				?c ?p1 ?o1 .
				<#{scientific_name}> ?p2 ?o2 
			})
	end

	def self.insert_svd_rdf(svd)
		%(INSERT DATA {
				<#{svd["uri"]}>
					a owl:Class;
					rdfs:subClassOf svf:SemanticVernacularDescription;
					svf:hasID "#{svd["id"]}"^^xsd:positiveInteger . 
			})
	end

	def self.delete_svd_rdf(svd)
		%(DELETE WHRE {
				<#{svd}> ?p ?o
			})
	end

	def self.insert_features_rdf(features)
		rdf = %(owl:equivalentClass
							[ a owl:class;
							owl:intersectionOf \(svf:Fungus )
		features.each do |feature|
			if feature["values"].length > 1
				rdf << %([ a owl:class;
									 owl:unionOf \()
				feature["values"].each do |value|
					rdf << insert_some_object_values_from_restriction_rdf(
						feature["feature"], value)
				end
				rdf << %(\)])
			end
			if feature["values"].length == 1
				rdf << insert_some_object_values_from_restriction_rdf(
					feature["feature"], feature["values"][0])
			end
		end
		rdf << %(\)])
	end

	def self.insert_has_object_value_restriction_rdf(property, value)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:hasValue <#{value}> ])
	end

	def self.insert_has_datatype_value_restriction_rdf(property, value, datatype)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:hasValue "#{value}"^^#{datatype} ])
	end

	def self.insert_some_object_values_from_restriction_rdf(property, value)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:someValuesFrom <#{value}> ])
	end

end