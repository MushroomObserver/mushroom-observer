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
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription .
			})
	end

	def self.query_svds_with_names
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?label
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription .
				?uri rdfs:subClassOf ?c .
				?c owl:onProperty svf:hasSVDName .
				?c owl:hasValue ?vl .
				?vl rdfs:label ?label
			})
	end

	def self.insert_rdf(svd)
		QUERY_PREFIX +
		%(INSERT DATA {
				<#{svd["uri"]}>
					a owl:Class;
					rdfs:subClassOf svf:SemanticVernacularDescription;
					svf:hasID "#{svd["id"]}"^^xsd:positiveInteger . 
			})
	end

	def self.delete_rdf(svd)
		QUERY_PREFIX +
		%(DELETE WHRE {
				<#{svd}> ?p ?o
			})
	end

	def query_name
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri
			WHERE {
				<#{@uri}> rdfs:subClassOf svf:SemanticVernacularDescription .
				<#{@uri}> rdfs:subClassOf ?c .
				?c owl:onProperty svf:hasSVDName .
				?c owl:hasValue ?uri . }
		)
	end

	def query_labels
		QUERY_PREFIX +
			%(SELECT DISTINCT ?uri
				WHERE {
					<#{@uri}> rdfs:subClassOf svf:SemanticVernacularDescription .
					<#{@uri}> rdfs:subClassOf ?c .
					?c owl:onProperty svf:hasLabel .
					?c owl:hasValue ?uri . }
			)
	end

	def query_definition
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri
			WHERE {
				<#{@uri}> rdfs:subClassOf svf:SemanticVernacularDescription .
				<#{@uri}> rdfs:subClassOf ?c .
				?c owl:onProperty svf:hasDefinition .
				?c owl:someValuesFrom ?uri . }
		)
	end

	def query_descriptions
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri
			WHERE {
				<#{@uri}> rdfs:subClassOf svf:SemanticVernacularDescription .
				<#{@uri}> rdfs:subClassOf ?c .
				?c owl:onProperty svf:hasDescription .
				?c owl:someValuesFrom ?uri . }
		)
	end	

	def query_scientific_names
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri
			WHERE {
				<#{@uri}> rdfs:subClassOf svf:SemanticVernacularDescription .
				<#{@uri}> rdfs:subClassOf ?c . 
				?c owl:onProperty svf:hasAssociatedScientificName .
				?c owl:someValuesFrom ?uri . }
		)
	end

end