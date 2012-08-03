class SVUser < SemanticVernacularDataSource

  attr_accessor :uri,
                :name,
                :email

  def initialize(uri)
    @uri = uri
    user = self.class.query(init_query)[0]
    @name = user["name"]["value"]
    @email = user["email"]["value"]
  end

  private

  def init_query
    QUERY_PREFIX +
    %(SELECT DISTINCT ?name ?email
      WHERE {
        <#{@uri}> a svf:User .
        <#{@uri}> svf:hasName ?name .
        <#{@uri}> svf:hasEmail ?email .
      })
  end

end