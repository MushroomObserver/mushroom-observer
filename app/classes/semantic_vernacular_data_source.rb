# encoding: utf-8
#
#  = Semantic Vernacular Data Source
#
#  This class describes the abstract data model for the semantic vernacular
#  system. Subclasses should override some of the methods to implement 
#  corresponding functionalities. Data are retrieved directly throug a triple 
#  store.
#
#  == Class Methods
#  === Public
#  index::    						List all instances.
#  === Private
#  query:: 								Submit a query to the triple store and get responses.
#  query_all:: 						Build a query to get all instances.
#  query_all_hierarchy:: 	Build a query to get all instances with hierarchy.
#
#  == Instance Methods
#  ==== Public
#  to_s::           			Returns the lable for a given instance.
#  get_label::						Returns the lable for a given instance.
#  get_properites:: 			Returns the properties for a given instance.
#  refactor_properties:: 	Refactor the property array returned by 
#  												get_properties. Combine hashes with identical keys.
#  ==== Private
#  query_label:: 					Build a query to get the lable for a given instance.
#  query_properties:: 		Build a query to get the properties for a given 
#  												instance.
#
################################################################################

class SemanticVernacularDataSource
	attr_accessor :uri, :label

	def initialize(uri)
		@uri = uri # String
		@label = get_label # String
	end

	# For subclasses to override.
	def self.index
	end

	def to_s
		@label
	end

	# Return: string
	def get_label
		self.class.query(query_label)[0]["label"]
	end

	# Return: array of hashes 
	# [{"property" => "property_1", "value" => "value_1"}, 
	#  {"property" => "property_2", "value" => "value_2"}, ...]
	def get_properties
		self.class.query(query_properties)
	end

	# Return: hash {"property_1" => "values_1", "property_2" => "values_2", ...}
	def refactor_properties
		properties = Hash.new
		get_properties.each do |property|
			key = property["property"]
			value = property["value"]
			if properties.has_key?(key) 
				properties[key].push(value)
			else
				properties[key] = Array.new
				properties[key].push(value)
			end
		end
		return properties
	end

	private
	
	ENDPOINT = "http://aquarius.tw.rpi.edu:2024/sparql"
	
	# Retrun: array of hashes
	# [{"key_1" => "value_1"}, {"key_2" => "value_2"}, ...]
	def self.query(query)
		sparql = SPARQL::Client.new(ENDPOINT)
  	response = sparql.query(query)
  end

  # Prefix for all SPARQL queries.
	QUERY_PREFIX = 
		%(PREFIX owl: <http://www.w3.org/2002/07/owl#>
			PREFIX rdfs: <http://www.w3.org/2000/01/rdf-schema#>
			PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>
			PREFIX sv: <http://aquarius.tw.rpi.edu/ontology/mushroom.owl#>\n)

	# For subclasses to override.
	def self.query_all
	end

	# For subclasses to override.
	def self.query_all_hierarchy
	end

	def query_label
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?label
			WHERE {
				<#{@uri}> rdfs:label ?label .
			})
	end

	# For subclasses to override.
	def query_properties
	end
	
end