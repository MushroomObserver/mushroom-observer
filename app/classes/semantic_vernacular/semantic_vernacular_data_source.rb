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

	def self.insert(uri)
		update(insert_rdf(uri))
	end

	def self.delete(uri)
		update(delete_rdf(uri))
	end

	def self.accept(uri)
		update(accept_rdf(uri))
	end

	private
	
	QUERY_ENDPOINT = "http://128.128.170.15:3030/svf/sparql"
	UPDATE_ENDPOINT = "http://128.128.170.15:3030/svf/update"
	#QUERY_ENDPOINT = "http://leo.tw.rpi.edu:2058/svf/sparql"
	#UPDATE_ENDPOINT = "http://leo.tw.rpi.edu:2058/svf/update"
	SVF_NAMESPACE = "http://mushroomobserver.org/svf.owl#"

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
			PREFIX svf: <#{SVF_NAMESPACE}>\n)

	def self.query_max_ID(type)
		query = QUERY_PREFIX + %(SELECT ?id WHERE {)
		case type
		when "SemanticVernacularDescription", "VernacularFeatureDescription", 
			"ScientificName"
			query << %(?uri rdfs:subClassOf+ svf:#{type} . )
		when "VernacularLabel", "User"
			query << %(?uri a/rdfs:subClassOf* svf:#{type} . )
		end
		query << "?uri svf:hasID ?id } ORDER BY DESC (?id) LIMIT 1"
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

	def self.insert_rdf(uri)
	end

	def self.delete_rdf(uri)
	end

	def self.accept_rdf(uri)
	end

end