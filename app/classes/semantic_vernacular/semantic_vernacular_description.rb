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

class SemanticVernacularDescription < SemanticVernacularDataSourceViaProxy
	
	# Return: array of hashes
	# [{"feature" => "feature_1", "value" => "value_1"}, 
	#  {"feature" => "feature_2", "value" => "value_2"}, ...]
	def get_features
		self.class.query(query_features)
	end

	# Return: hash {"feature_1" => "values_1", "feature_2" => "values_2", ...}
	def refactor_features
		features = Hash.new
		get_features.each do |feature|
			key = feature["feature"].to_s
			value = feature["value"].to_s
			if features.has_key?(key) 
				features[key].push(value)
			else
				features[key] = Array.new
				features[key].push(value)
			end
		end
		return features
	end

	# Return: array of hashes {"species" => speices}
	def associate_taxa
		taxa = Array.new
		refactor_features.each do |feature, values|
			taxa << self.class.query(query_feature_to_taxa(feature, values))
		end
	return taxa.inject(:&)
	end

	private

	def self.query_all
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?uri ?label ?parent
			WHERE { 
			?uri rdfs:subClassOf+ sv:FungusDescriptiveVernacular .
			?uri rdfs:label ?label . 
			?uri rdfs:subClassOf ?parent .
			?parent rdfs:subClassOf+ sv:Fungus .
			})
	end

	def query_features
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?feature ?value
			WHERE {
			<#{@uri}> owl:equivalentClass ?class .
			?class owl:intersectionOf ?list . 
			{ ?list rdf:rest*/rdf:first ?member . } UNION
			{ ?list rdf:rest*/rdf:first ?m .
			  ?m owl:unionOf ?union .
				?union rdf:rest*/rdf:first ?member . }
			?member a owl:Restriction . 
			?member owl:onProperty ?p .
			?member owl:someValuesFrom ?v .
			?p rdfs:label ?feature .
			?v rdfs:label ?value .
			})
	end

	def query_feature_to_taxa(feature, values)
		query = QUERY_PREFIX + 
		%(SELECT DISTINCT ?uri
			WHERE {
				{ ?uri rdfs:subClassOf ?class .
					?class owl:unionOf ?list . 
					?list rdf:rest*/rdf:first ?member . } UNION 
				{ ?uri rdfs:subClassOf ?member }
				?member a owl:Restriction .
				?member owl:onProperty ?p .
				?member owl:someValuesFrom ?v .)
		q = Array.new
		values.each do |value|
			q << %({ ?p rdfs:label "#{feature}"^^rdfs:Literal .
							 ?v rdfs:label "#{value}"^^rdfs:Literal . })
		end
		query << q.join(" UNION ") << "}"
	end
end