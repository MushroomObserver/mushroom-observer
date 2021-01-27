# frozen_string_literal: true

module Report
  class Gbif < Report::ZipReport
    attr_accessor :images, :observations

    def initialize(args)
      super(args)
      self.images = Darwin::GbifImages.new(args)
      args[:observations] = images.observations
      self.observations = Darwin::ImageObservations.new(args)
    end

    def filename
      "gbif.#{extension}"
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
