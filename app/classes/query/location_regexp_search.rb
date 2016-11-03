class Query::LocationRegexpSearch < Query::LocationBase

  def parameter_declarations
    super.merge(
      regexp: :string
    )
  end

  def initialize_flavor
    regexp = params[:regexp].to_s.strip_squeeze
    regexp = Location.connection.quote_string(regexp)
    self.where += ["locations.name REGEXP '#{regexp}'"]
    super
  end
end
