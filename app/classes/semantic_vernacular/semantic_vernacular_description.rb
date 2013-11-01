# encoding: utf-8
#
#  = Semantic Vernacular Description
#
#  This class describes the data model for the class 
#  SemanticVernacularDescription, a subclass of SemanticVernacularDataSource.
#
#  == Class Methods
#  === Public
#  index_with_name::					List all instances with accepted names.
#  index_without_name::  			List all instances without accepted names.
#  insert::  									Inherit the parent class method.
#  delete:: 									Inherit the parent class method.
#  === Private
#  query_svds_all::						Build a SPARQL query to get all instances.
#  query_svds_with_names:: 		Build a SPARQL query to get all instances with
#  														names.
#  insert_triples:: 					Overrdie the parent class method.
#  delete_triples::  					Override the parent class method.
#
#  == Instance Methods
#  ==== Public
#  get_attribute:: 						Get a specific single-value attribute of an 
# 														instance.
#  get_attribute_array:: 			Get a specific multiple-value attribute of an 
#  														instance.
#  ==== Private
#  query_name:: 							Build a SPARQL query for getting the name.
#  query_labels:: 						Build a SPARQL query for getting the name 
# 														proposals.
#  query_definition:: 				Build a SPARQL query for getting the definition.
#  query_descriptions:: 			Build a SPARQL query for getting the definition 
# 														proposals.
#  query_scentific_names:: 		Build a SPARQL query for getting the scientific 
# 														names.
#  query_attribute:: 					A helper method for building SPARQL queries. 
#
################################################################################

class SemanticVernacularDescription < SemanticVernacularDataSource

	attr_accessor :uri

  # Fillin any stuff that's provided in the args
	def initialize(args)
	  if args.class == String
	    args = {:uri => args}
	  end
		@uri = args[:uri]
		@name = args[:name]
		@labels = args[:labels]
		@definition = args[:definition]
		@descriptions = args[:descriptions]
		@scientific_names = args[:scientific_names]
	end
	
	# Make these lazy loading
	def name; @name.nil? ? @name = get_attribute("name") : @name; end
	def name=(name); @name = name; end
	
	def labels; @labels.nil? ? @labels = get_attribute_array("labels") : @labels; end
	def labels=(labels); @labels = labels; end
	
	def definition; @definition.nil? ? @definition = get_attribute("definition") : @definition; end
	def definition=(definition); @definition = definition; end
	
	def descriptions; @descriptions.nil? ? @descriptions = get_attribute_array("descriptions") : @descriptions; end
	def descriptions=(descriptions); @descriptions = descriptions; end
	
	def scientific_names; @scientific_names.nil? ? @scientific_names = get_attribute_array("scientific_names") : @scientific_names; end
	def scientific_names=(scientific_names); @scientific_names = scientific_names; end

	def self.index_with_name
		query(query_svds_with_names).sort_by!{ |row| row["label"]["value"]}
	end

  def self.svds_with_name
    index_with_name.collect {|row|
      print "#{row}\n"
      SemanticVernacularDescription.new(:uri => row["uri"]["value"])
    }
  end
  
	def self.index_without_name
		(query(query_svds_all).collect {|svd| svd["uri"]["value"]} -
			index_with_name.collect {|svd| svd["uri"]["value"]}).sort!
	end

  def self.svds_without_name
    index_without_name.collect {|uri| SemanticVernacularDescription.new(uri)}
  end
  
  def id
    @uri.split("#")[1]
  end
  
  def best_name
    if name
      name.label
    elsif labels != []
      labels.collect {|label| "\"#{label.label}\""}.join(", ")
    else
      id
    end
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
	# A hash listing the class of each attribute.
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
			FROM <#{SVF_GRAPH}>
			WHERE {
				?uri rdfs:subClassOf svf:SemanticVernacularDescription . })
	end

	def self.query_svds_with_names
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri ?label
			FROM <#{SVF_GRAPH}>
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
					svf:hasID "#{svd["id"]}"^^xsd:integer . }})
	end

	def self.delete_triples(svd)
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

	def query_attribute(property, value_constraint)
		QUERY_PREFIX +
		%(SELECT DISTINCT ?uri
			FROM <#{SVF_GRAPH}>
			WHERE {
				<#{@uri}> rdfs:subClassOf svf:SemanticVernacularDescription .
				<#{@uri}> rdfs:subClassOf ?c .
				?c owl:onProperty #{property} .
				?c #{value_constraint} ?uri . })
	end

end