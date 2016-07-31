module Query::Initializers::PatternSearch
  def google_parse_pattern
    pattern = params[:pattern].to_s.strip_squeeze
    clean = clean_pattern(pattern)
    google_parse(clean)
  end

  def add_search_conditions(search, *val_specs)
    val_spec = "CONCAT(" + val_specs.join(",") + ")"
    self.where += google_conditions(search, val_spec)
  end
end
