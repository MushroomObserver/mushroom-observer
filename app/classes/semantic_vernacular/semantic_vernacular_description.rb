# encoding: utf-8
#
#  = Semantic Vernacular Description (SVD)
#
#  This class is a subclass of the SemanticVernacularDataSource class. It 
#  describes the data model of semantic vernacular descriptions.
#
#  == Class Methods
#  === Public
#  index (inherited)::				List all SVD instances.
#  === Private
#  query (inherited)::				Submit a SPARQL query and get responses.
#  query_all:: 								Build a query to get all SVD instances.
#
#  == Instance Methods
#  ==== Public
#  to_s (inherited):: 				Returns the lable for a given SVD instance.
#  get_label (inherited)::		Returns the lable for a given SVD instance.
#  associate_taxa::						Associate a SVD instance to taxa.
#  
#  ==== Private
#  query_label (inherited)::	Build a query to get the lable for a given SVD
#  														instance.
#  query_features:: 					Build a query to get the features for a given SVD
#  														instance.
#  query_feature_to_taxa::  	Build a query to get the associated taxa for a 
#  														given pair of feature and values.  
#
################################################################################

class SemanticVernacularDescription < SemanticVernacularDataSource

	attr_accessor :uri,
								:name,
								:labels,
								:definition,
								:descriptions,
								:scientific_names

	def initialize(uri)
		@uri = uri
		@name = get_attribute("name")
		@labels = get_attribute_array("labels")
		@definition = get_attribute("definition")
		@descriptions = get_attribute_array("descriptions")
		@scientific_names = get_attribute_array("scientific_names")
	end

	def self.index_with_name
		query(query_svds_with_names)
	end

	def self.index_without_name
		query(query_svds_all).collect {|svd| svd["uri"]["value"]} -
			index_with_name.collect {|svd| svd["uri"]["value"]}
	end

	def get_attribute(type)
		attribute = nil
		result = self.class.query(eval("query_" + type))[0]
		if result != nil
			attribute_class = ATTRIBUTE_CLASS_LIST[type.to_sym].constantize
			attribute = attribute_class.new(result["uri"]["value"])
		end
		return attribute
	end

	def get_attribute_array(type)
		attribute_array = Array.new()
		attribute_class = ATTRIBUTE_CLASS_LIST[type.to_sym].constantize
		self.class.query(eval("query_" + type)).each do |result|
			attribute_array.push(attribute_class.new(result["uri"]["value"]))
		end
		return attribute_array
	end

	private

	ATTRIBUTE_CLASS_LIST = {
		:name => "VernacularLabel",
		:labels => "VernacularLabel",
		:definition => "VernacularFeatureDescription",
		:descriptions => "VernacularFeatureDescription",
		:scientific_names => "ScientificName"
	}

	def self.query_svds_all
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri
			FROM NAMED <#{SVF_GRAPH}>
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription . })
	end

	def self.query_svds_with_names
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?label
			FROM NAMED <#{SVF_GRAPH}>
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription .
				?uri rdfs:subClassOf ?c .
				?c owl:onProperty svf:hasSVDName .
				?c owl:hasValue ?vl .
				?vl rdfs:label ?label . })
	end

	def self.insert_triples(svd)
		QUERY_PREFIX +
		%(INSERT DATA {
			GRAPH <#{SVF_GRAPH}> {
				<#{svd["uri"]}>
					a owl:Class;
					rdfs:subClassOf svf:SemanticVernacularDescription;
					svf:hasID "#{svd["id"]}"^^xsd:positiveInteger . }})
	end

	def self.delete_triples(svd)
	end

	def query_attribute(property, value_constraint)
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri
			WHERE {
				<#{@uri}> rdfs:subClassOf svf:SemanticVernacularDescription .
				<#{@uri}> rdfs:subClassOf ?c .
				?c owl:onProperty #{property} .
				?c #{value_constraint} ?uri . })
	end

	def query_name
		query_attribute("svf:hasSVDName", "owl:hasValue")
	end

	def query_labels
		query_attribute("svf:hasLabel", "owl:hasValue")
	end

	def query_definition
		query_attribute("svf:hasDefinition", "owl:someValuesFrom")
	end

	def query_descriptions
		query_attribute("svf:hasDescription", "owl:someValuesFrom")
	end	

	def query_scientific_names
		query_attribute("svf:hasAssociatedScientificName", "owl:someValuesFrom")
	end

end