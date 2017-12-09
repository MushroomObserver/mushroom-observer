module Query
  # Parent taxa containing a given name.
  class NameOfParents < Query::NameBase
    def parameter_declarations
      super.merge(
        name: Name,
        all?: :boolean
      )
    end

    def initialize_flavor
      name = find_cached_parameter_instance(Name, :name)
      title_args[:name] = name.display_name
      all = params[:all] || false
      set = clean_id_set(name.parents(all).map(&:id))
      where << "names.id IN (#{set})"
      super
    end
  end
end
