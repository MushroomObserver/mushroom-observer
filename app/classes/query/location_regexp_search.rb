class Query::LocationRegexpSearch < Query::Location

  def parameter_declarations
    super.merge(
      regexp: :string
    )
  end

  def initialize_flavor
    regexp = params[:regexp].to_s.strip_squeeze
    self.where += ["locations.name REGEXP '#{Location.connection.quote_string(regexp)}'"]
    super
  end
end
