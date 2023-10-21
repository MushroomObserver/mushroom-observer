# frozen_string_literal: true

module Report
  # Darwin Core Archive format.
  class Dwca < ZipReport
    attr_accessor :images, :observations

    def initialize(args)
      super(args)
      self.observations = Darwin::Observations.new(args)
      args[:observations] = observations
      self.images = Darwin::ObservationImages.new(args)
    end

    def filename
      "dwca.#{extension}"
    end

    # generate CSV & meta.xml and bundle into a Zip
    def render
      path = Rails.public_path.join("dwca/gbif_meta.xml")
      content << ["meta.xml", path.read]
      content << ["observations.csv", observations.render]
      content << ["multimedia.csv", images.render]
      super
    end
  end
end
