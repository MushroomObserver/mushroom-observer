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
		Rails.logger.debug(insert_update(label_rdf(svd, label, user)))
		update(insert_update(label_rdf(svd, label, user)))
	end

	def self.delete_label(svd_uri, label_uri, label_id, label)
		
	end

	def self.test
		definition_rdf("<#{svd_uri}>", "label_uri", 32, "label", "user_uri")
	end

	private
	
	QUERY_ENDPOINT = "http://128.128.170.15:3030/svf/sparql"
	#QUERY_ENDPOINT = "http://aquarius.tw.rpi.edu:2024/sparql"
	#QUERY_ENDPOINT = "http://leo.tw.rpi.edu:2058/svf/sparql"
	UPDATE_ENDPOINT = "http://128.128.170.15:3030/svf/update"
	SVF_NAMESPACE = "http://mushroomobserver.org/svf.owl#"

	# Retrun: array of hashes
	# [{"key_1" => "value_1"}, {"key_2" => "value_2"}, ...]
	def self.query2(query)
		sparql = SPARQL::Client.new(QUERY_ENDPOINT)
  	response = sparql.query(query).to_a # RDF::Query::Solution
  end

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
		when "SemanticVernacularDescription", "VernacularDefinition", "ScientificName"
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
				#{has_value_object_restriction_rdf("svf:hasLabel", label["uri"])} . 
			<#{label["uri"]}>
				a owl:NamedIndividual, svf:VernacularLabel;
				rdfs:label "#{label["value"]}"^^rdfs:Literal;
				svf:hasID "#{label["id"]}"^^xsd:positiveInteger;
				svf:isDefault "false"^^xsd:boolean;
				svf:proposedAt "#{Time.now.strftime("%FT%T%:z")}"^^xsd:dateTime;
				svf:proposedBy <#{user["uri"]}> . )
	end

	# def self.definition_rdf(svd, label, user)
	# 	rdf = %(
	# 		<#{definition["uri"]}>
	# 			a owl:class;
	# 			rdfs:subClassOf
	# 				#{has_value_object_restriction_rdf("svf:proposedBy", user["uri"])};
	# 				#{has_value_datatype_restriction_rdf("svf:proposedAt", )}
	# 			rdfs:subClassOf
	# 				[ a owl:Restriction;
	# 					owl:onProperty svf:proposedAt
	# 					owl:hasValue "#{Time.now.strftime("%FT%T%:z")}"^^xsd:dateTime
	# 				];
	# 	)			
	# end

	def self.has_value_object_restriction_rdf(property, value)
		%([ a owl:Restriction;
				owl:onProperty #{property};
				owl:hasValue <#{value}> ])
	end

end