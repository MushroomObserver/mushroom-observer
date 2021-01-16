# frozen_string_literal: true

module Report
  # Darwin Core Archive format.
  class Eol < Report::ZipReport
    attr_accessor :images, :observations, :taxa

    def initialize(args)
      super(args)
      self.images = Darwin::TaxonImages.new(args)
      args[:taxa] = images.taxa
      self.taxa = Darwin::ImageTaxa.new(args)
    end

    def filename
      "eol.#{extension}"
    end

    # generate CSV & meta.xml and bundle into a Zip
    def render
      filename = "#{::Rails.root}/public/dwca/eol_meta.xml"
      content << ["meta.xml", File.open(filename).read]
      content << ["taxa.csv", taxa.render]
      content << ["multimedia.csv", images.render]
      super
    end
  end
end
