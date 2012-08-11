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

class SemanticVernacularDataSource

	def self.ask_max_ID
		query(query_max_ID)
	end

	def self.id_to_uri(id)
		SVF_NAMESPACE + "SV" + id.to_s
	end

	def self.insert(uri)
		Rails.logger.debug(insert_triples(uri))
		update(insert_triples(uri))
	end

	def self.delete(uri)
		update(delete_triples(uri))
	end

	def self.accept(uri)
		Rails.logger.debug(accept_triples(uri))
		update(accept_triples(uri))
	end

	private
	
	# MBL endpoint
	QUERY_ENDPOINT = "http://128.128.170.15:3030/svf/sparql"
	UPDATE_ENDPOINT = "http://128.128.170.15:3030/svf/update"
	# RPI endpoint
	#QUERY_ENDPOINT = "http://leo.tw.rpi.edu:2058/svf/sparql"
	#UPDATE_ENDPOINT = "http://leo.tw.rpi.edu:2058/svf/update"
	SVF_GRAPH = "http://mushroomobserver.org/svf.owl"
	SVF_NAMESPACE = SVF_GRAPH + "#"
	
	# Build a SPARQL SELECT query
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

	# Build a SPARQL update query
  def self.update(query)
		Net::HTTP.post_form(URI(UPDATE_ENDPOINT), "update" => query)
  end

  # Prefix for all SPARQL queries.
	QUERY_PREFIX = 
		%(PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX xsd: <http://www.w3.org/2001/XMLSchema#>
			PREFIX dcterms: <http://purl.org/dc/terms/>
			PREFIX svf: <#{SVF_NAMESPACE}>\n)

	def self.query_max_ID
		QUERY_PREFIX + 
		%(SELECT ?id 
			FROM NAMED <#{SVF_GRAPH}>
			WHERE {
				?uri svf:hasID ?id } 
			ORDER BY DESC (?id) LIMIT 1)
	end

	def self.insert_has_object_value_restriction_triples(property, value)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:hasValue <#{value}> ])
	end

	def self.insert_has_datatype_value_restriction_triples(property, value, datatype)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:hasValue "#{value}"^^#{datatype} ])
	end

	def self.insert_some_object_values_from_restriction_triples(property, value)
		%([ a owl:Restriction;
				owl:onProperty <#{property}>;
				owl:someValuesFrom <#{value}> ])
	end

	def self.insert_triples(uri)
	end

	def self.delete_triples(uri)
	end

	def self.accept_triples(uri)
	end

end