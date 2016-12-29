module Query
  # Images in a given set.
  class ImageInSet < Query::ImageBase
    def parameter_declarations
      super.merge(
        ids: [Image]
      )
    end

    def initialize_flavor
      initialize_in_set_flavor("images")
      super
    end
  end
end
