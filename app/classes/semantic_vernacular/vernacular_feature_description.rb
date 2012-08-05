class VernacularFeatureDescription < SemanticVernacularDataSource

  attr_accessor :uri,
                :creator,
                :created_date_time,
                :features

  def initialize(uri)
    @uri = uri
    desc = self.class.query(query_attributes)[0]
    @creator = SVUser.new(desc["user"]["value"])
    @created_date_time = desc["dateTime"]["value"]
    @features = refactor_features
  end

  def self.insert(svd, description, features, user)
    update(insert_triples(svd, description, features, user))
  end

  private

  def get_features
    self.class.query(query_features)
  end

  def refactor_features
    refactoring = Hash.new
    get_features.each do |feature|
      key = {"uri"=>feature["f"]["value"], "label"=>feature["feature"]["value"]}
      value = {"uri"=>feature["v"]["value"], "label"=>feature["value"]["value"]}
      if refactoring.has_key?(key) 
        refactoring[key].push(value)
      else
        refactoring[key] = Array.new
        refactoring[key].push(value)
      end
    end
    return refactoring
  end

  def query_attributes
    QUERY_PREFIX +
    %(SELECT DISTINCT ?user ?dateTime
      WHERE {
        <#{@uri}> rdfs:subClassOf+ svf:VernacularFeatureDescription .
        <#{@uri}> rdfs:subClassOf ?c1 .
        ?c1 owl:onProperty svf:proposedBy .
        ?c1 owl:hasValue ?user .
        <#{@uri}> rdfs:subClassOf ?c2 .
        ?c2 owl:onProperty svf:proposedAt .
        ?c2 owl:hasValue ?dateTime . })
  end

  def query_features
    QUERY_PREFIX +
    %(SELECT DISTINCT ?f ?v ?feature ?value
      WHERE {
        <#{@uri}> rdfs:subClassOf+ svf:VernacularFeatureDescription .
        <#{@uri}> owl:equivalentClass ?c1 .
        ?c1 owl:intersectionOf ?c2 . 
        { ?c2 rdf:rest+/rdf:first ?c3 . } UNION
        { ?c2 rdf:rest+/rdf:first ?c4 .
          ?c4 owl:unionOf ?c5 .
          ?c5 rdf:rest+/rdf:first ?c3 . }
        ?c3 owl:onProperty ?f .
        ?c3 owl:someValuesFrom ?v .
        ?f rdfs:subPropertyOf+ svf:hasFungalFeature .
        ?f rdfs:label ?feature .
        ?v rdfs:label ?value . })
  end

  def self.insert_triples(svd, description, features, user)
    QUERY_PREFIX +
    %(INSERT DATA {
        <#{svd["uri"]}> 
          rdfs:subClassOf
            #{insert_some_object_values_from_restriction_triples(
              SVF_NAMESPACE + "hasDescription", description["uri"])} .
        <#{description["uri"]}>
          a owl:class;
          rdfs:subClassOf svf:VernacularFeatureDescription;
          rdfs:subClassOf
            #{insert_has_object_value_restriction_triples(
              SVF_NAMESPACE + "proposedBy", user["uri"])};
          rdfs:subClassOf
            #{insert_has_datatype_value_restriction_triples(
              SVF_NAMESPACE + "proposedAt", 
              Time.now.strftime("%FT%T%:z"), 
              "xsd:dateTime")};
          svf:hasID "#{description["id"]}"^^xsd:positiveInteger;
          #{insert_features_triples(features)} . })      
  end

  def self.delete_triples(description)
    QUERY_PREFIX +
    %(DELETE {
        ?svd rdfs:subClassOf ?c . 
        ?c ?p1 ?o1 . 
        <#{description}> ?p2 ?o2 .
        ?o3 ?p4 ?o4 .
        ?list ?p6 ?o6 .
        ?z rdf:first ?head .
        ?z rdf:rest ?tail .
        ?head ?p7 ?o7 . }
      WHERE {
        ?svd rdfs:subClassOf ?c .
        ?c owl:someValuesFrom <#{description}> .
        ?c ?p1 ?o1 .
        <#{description}> ?p2 ?o2 .
        <#{description}> ?p3 ?o3 .
        ?o3 ?p4 ?o4 .
        <#{description}> owl:equivalentClass ?o5 .
        ?o5 owl:intersectionOf ?list .
        ?list ?p6 ?o6 .
        ?list rdf:rest* ?z .
        ?z rdf:first ?head .
        ?head ?p7 ?o7 .
        ?z rdf:rest ?tail .
        FILTER isBlank(?o3) . })
  end

  def self.accept_triples(uri)
    QUERY_PREFIX +
    %(DELETE { 
        ?c1 owl:onProperty svf:hasDescription .
        ?c2 owl:onProperty svf:hasDefinition . }
      INSERT { 
        ?c1 owl:onProperty svf:hasDefinition .
        ?c2 owl:onProperty svf:hasDescription . }
      WHERE {
        ?svd rdfs:subClassOf svf:SemanticVernacularDescription .
        ?svd rdfs:subClassOf ?c1 .
        ?c1 owl:onProperty svf:hasDescription . 
        ?c1 owl:someValuesFrom <#{uri}> .
        OPTIONAL { ?svd rdfs:subClassOf ?c2 .
        ?c2 owl:onProperty svf:hasDefinition . 
        ?c2 owl:someValuesFrom ?name . }})
  end

  def self.insert_features_triples(features)
    rdf = %(owl:equivalentClass
              [ a owl:class;
              owl:intersectionOf \(svf:Fungus )
    features.each do |feature|
      if feature["values"].length > 1
        rdf << %([ a owl:class;
                   owl:unionOf \()
        feature["values"].each do |value|
          rdf << insert_some_object_values_from_restriction_triples(
            feature["feature"], value)
        end
        rdf << %(\)])
      end
      if feature["values"].length == 1
        rdf << insert_some_object_values_from_restriction_triples(
          feature["feature"], feature["values"][0])
      end
    end
    rdf << %(\)])
  end

end