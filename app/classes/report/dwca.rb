# frozen_string_literal: true

module Report
  # Darwin Core Archive format.
  class Dwca < Report::ZipReport
    attr_accessor :images, :observations

    def initialize(args)
      super(args)
      self.observations = Darwin::Observations.new(args)
      args[:observations] = observations
      self.images = Darwin::Images.new(args)
    end

    def filename
      "dwca.#{extension}"
    end

    # generate CSV & meta.xml and bundle into a Zip
    def render
      filename = "#{::Rails.root}/public/dwca/gbif_meta.xml"
      content << ["meta.xml", File.open(filename).read]
      content << ["observations.csv", observations.render]
      content << ["multimedia.csv", images.render]
      super
    end
  end
end
