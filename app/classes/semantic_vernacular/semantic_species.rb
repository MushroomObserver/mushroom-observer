class SemanticSpecies < SemanticVernacularDataSourceViaProxy

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

	# Return: array of hashes
	# [{"link" => "link_1", "url" => "url_1"}, 
	#  {"link" => "link_2", "url" => "url_2"}, ...]
	def get_links
		self.class.query(query_links)
	end

	private
	
	def self.query_all
		QUERY_PREFIX + 
		%(SELECT DISTINCT ?uri ?label
			WHERE { 
				?uri rdfs:subClassOf sv:FungusSpecies .
				?uri rdfs:label ?label .
			})
	end

	def self.query_all_hierarchy
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?label ?parent
			WHERE { 
			?uri rdfs:subClassOf+ sv:FungusSpecies .
			?uri rdfs:label ?label . 
			?uri rdfs:subClassOf ?parent .
			?parent rdfs:subClassOf+ sv:Fungus .
			})
	end

	def query_features
		QUERY_PREFIX +
		%(SELECT DISTINCT ?feature ?value
			WHERE {
				{ <#{@uri}> rdfs:subClassOf ?class .
					?class owl:unionOf ?list .
					?list rdf:rest*/rdf:first ?member . } UNION
				{ <#{@uri}> rdfs:subClassOf ?member . }
				?member a owl:Restriction .
				?member owl:onProperty ?p .
				?member owl:someValuesFrom ?v .
				?p rdfs:label ?feature .
				?v rdfs:label ?value .
			})
	end

	def query_links
		QUERY_PREFIX +
		%(SELECT DISTINCT ?link ?url
			WHERE {
				<#{@uri}> ?l ?url .
				?l rdfs:subPropertyOf rdfs:seeAlso .
				?l rdfs:label ?link .
			})
	end
end