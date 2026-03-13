# frozen_string_literal: true

module Mappable
  class MinimalLocation < Box
    attribute :id, :integer
    attribute :name, :string

    validates :id, presence: true
    validates :name, presence: true

    def display_name
      if ::User.current_location_format == "scientific"
        ::Location.reverse_name(name)
      else
        name
      end
    end
  end
end
