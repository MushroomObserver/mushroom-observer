# frozen_string_literal: true

namespace :app do
  task(name_primer: :environment) do
    open("name_primer.json", "w") do |f|
      f.write(ActiveSupport::JSON.encode(
                Name.order(:id).joins(:observations).
                  distinct.select(:id, :text_name, :deprecated,
                                  :synonym_id, :author)
              ))
    end
  end

  task(location_primer: :environment) do
    open("location_primer.json", "w") do |f|
      f.write(ActiveSupport::JSON.encode(
                Location.order(:id).select(:id, :name)
              ))
    end
  end
end
