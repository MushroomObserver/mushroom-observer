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
								:default_label,
								:other_labels,
								:default_definition,
								:other_definitions,
								:associated_scientific_names

	def initialize(uri)
		@uri = uri
		@default_label = get_default_label[0]
		@other_labels = get_other_labels
		@default_definition = get_default_definition[0]
		@other_definitions = get_other_definitions
		@associated_scientific_names = get_associated_scientific_names
	end
	
	def self.index
		query(query_all)
	end

	def get_labels
		self.class.query(query_labels)
	end

	def get_default_label
		get_labels.select { |label| label["default"]["value"] == "true" }
	end

	def get_other_labels
		get_labels.select { |label| label["default"]["value"] == "false" }
	end

	def get_definitions
		self.class.query(query_definitions)
	end

	def get_default_definition
		get_definitions.select do |definition| 
			definition["default"]["value"] == "true"
		end
	end

	def get_other_definitions
		get_definitions.select do |definition| 
			definition["default"]["value"] == "false"
		end
	end

	def get_associated_scientific_names
		self.class.query(query_associated_scientific_names)
	end

	# Return: array of hashes
	# [{"feature" => "feature_1", "value" => "value_1"}, 
	#  {"feature" => "feature_2", "value" => "value_2"}, ...]
	def get_features(desc)
		self.class.query(query_features(desc))
	end

	# Return: hash {"feature_1" => "values_1", "feature_2" => "values_2", ...}
	def refactor_features(features)
		refactoring = Hash.new
		features.each do |feature|
			key = feature["feature"]["value"]
			value = feature["value"]["value"]
			if refactoring.has_key?(key) 
				refactoring[key].push(value)
			else
				refactoring[key] = Array.new
				refactoring[key].push(value)
			end
		end
		return refactoring
	end

	# Return: array of hashes {"species" => speices}
	# def associate_taxa
	# 	taxa = Array.new
	# 	refactor_features.each do |feature, values|
	# 		taxa << self.class.query(query_feature_to_taxa(feature, values))
	# 	end
	# return taxa.inject(:&)
	# end

	private

	def self.query_all
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?label
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription .
				?uri rdfs:subClassOf ?c .
				?c owl:onProperty svf:hasLabel .
				?c owl:hasValue ?vl .
				?vl rdfs:label ?label .
				?vl svf:isDefault "true"^^xsd:boolean .
			})
	end

	def query_labels
		QUERY_PREFIX +
		%(SELECT DISTINCT ?label ?user ?email ?dateTime ?default
			WHERE {
				<#{@uri}> rdfs:subClassOf ?c1 .
				?c1 owl:onProperty svf:hasLabel .
				?c1 owl:hasValue ?vl .
				?vl rdfs:label ?label .
				?vl svf:isDefault ?default .
				?vl svf:proposedBy ?u .
				?u svf:hasName ?user .
				?u svf:hasEmail ?email .
				?vl svf:proposedAt ?dateTime .
			})
	end

	def query_definitions
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?user ?email ?dateTime ?default
			WHERE {
				<#{@uri}> rdfs:subClassOf ?c1 .
				?c1 owl:onProperty svf:hasDefinition .
				?c1 owl:someValuesFrom ?uri .
				?uri rdfs:subClassOf ?c2 .
				?c2 owl:onProperty svf:isDefault .
				?c2 owl:hasValue ?default .
				?uri rdfs:subClassOf ?c3 .
				?c3 owl:onProperty svf:proposedBy .
				?c3 owl:hasValue ?u .
				?uri rdfs:subClassOf ?c4 .
				?c4 owl:onProperty svf:proposedAt .
				?c4 owl:hasValue ?dateTime .
				?u svf:hasName ?user .
				?u svf:hasEmail ?email .
			})
	end

	def query_associated_scientific_names
		QUERY_PREFIX +
		%(SELECT DISTINCT ?label ?moURL ?moID
			WHERE {
				<#{@uri}> rdfs:subClassOf ?c1 .
				?c1 owl:onProperty svf:hasAssociatedScientificName .
				?c1 owl:someValuesFrom ?sn .
				?sn rdfs:label ?label .
				OPTIONAL { ?sn svf:hasMushroomObserverURL ?moURL } .
				OPTIONAL { ?sn owl:equivalentClass ?c2 .
				?c2 owl:onProperty svf:hasMONameId .
				?c2 owl:hasValue ?moID } .
			})
	end

	def query_features(desc)
		QUERY_PREFIX +
		%(SELECT DISTINCT ?feature ?value
			WHERE {
			<#{desc}> owl:equivalentClass ?c1 .
			?c1 owl:intersectionOf ?c2 . 
			{ ?c2 rdf:rest+/rdf:first ?c3 . } UNION
			{ ?c2 rdf:rest+/rdf:first ?c4 .
			  ?c4 owl:unionOf ?c5 .
				?c5 rdf:rest+/rdf:first ?c3 . }
			?c3 owl:onProperty ?f .
			?c3 owl:someValuesFrom ?v .
			?f rdfs:subPropertyOf+ svf:hasFungalFeature .
			?f rdfs:label ?feature .
			?v rdfs:label ?value .
			})
	end

	# def query_feature_to_taxa(feature, values)
	# 	query = QUERY_PREFIX + 
	# 	%(SELECT DISTINCT ?uri
	# 		WHERE {
	# 			{ ?uri rdfs:subClassOf ?class .
	# 				?class owl:unionOf ?list . 
	# 				?list rdf:rest*/rdf:first ?member . } UNION 
	# 			{ ?uri rdfs:subClassOf ?member }
	# 			?member a owl:Restriction .
	# 			?member owl:onProperty ?p .
	# 			?member owl:someValuesFrom ?v .)
	# 	q = Array.new
	# 	values.each do |value|
	# 		q << %({ ?p rdfs:label "#{feature}"^^rdfs:Literal .
	# 						 ?v rdfs:label "#{value}"^^rdfs:Literal . })
	# 	end
	# 	query << q.join(" UNION ") << "}"
	# end

end