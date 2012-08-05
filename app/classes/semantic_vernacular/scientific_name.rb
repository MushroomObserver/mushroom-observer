class ScientificName < SemanticVernacularDataSource

  attr_accessor :uri,
                # :creator,
                # :created_date_time,
                :label,
                :moURL,
                :moID

  def initialize(uri)
    @uri = uri
    sn = self.class.query(query_attributes)[0]
    @label = sn["label"]["value"]
    # @creator = SVUser.new(desc["user"]["value"])
    # @created_date_time = desc["dateTime"]["value"]
    @moURL = sn["moURL"] == nil ? nil : sn["moURL"]["value"]
    @moID = sn["moID"] == nil ? nil : sn["moID"]["value"]
  end

  def self.insert(svd, scientific_names)
    update(insert_triples(svd, scientific_names))
  end

  private

  def query_attributes
    QUERY_PREFIX +
    %(SELECT DISTINCT ?label ?moURL ?moID
      WHERE {
        <#{@uri}> rdfs:subClassOf svf:ScientificName .
        <#{@uri}> rdfs:label ?label .
        OPTIONAL { <#{@uri}> svf:hasMushroomObserverURL ?moURL } .
        OPTIONAL { <#{@uri}> owl:equivalentClass ?c .
        ?c owl:onProperty svf:hasMONameId .
        ?c owl:hasValue ?moID . }})
  end

  def self.insert_triples(svd, scientific_names)
    rdf = QUERY_PREFIX + %(INSERT DATA {)
    scientific_names.each do |scientific_name|
      rdf << 
        %(<#{svd["uri"]}>
            rdfs:subClassOf
              #{insert_some_object_values_from_restriction_triples(
                SVF_NAMESPACE + "hasAssociatedScientificName", 
                scientific_name["uri"])} . 
          <#{scientific_name["uri"]}>
            rdfs:subClassOf svf:ScientificName;
            rdfs:label "#{scientific_name["label"]}"^^rdfs:Literal;
            svf:hasID "#{scientific_name["id"]}"^^xsd:positiveInteger . )
    end
    rdf << %(})
    return rdf
  end

  def self.delete_triples(scientific_name)
    QUERY_PREFIX +
    %(DELETE WHERE {
        ?svd rdfs:subClassOf ?c . 
        ?c owl:someValuesFrom <#{scientific_name}> .
        ?c ?p1 ?o1 .
        <#{scientific_name}> ?p2 ?o2 . })
  end

end