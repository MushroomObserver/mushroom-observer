# frozen_string_literal: true

# private methods shared by DonwloadsController and NameListsController
module SpeciesLists
  module SharedRenderMethods
    def render_name_list_as_txt(names)
      charset = "UTF-8"
      str = "\xEF\xBB\xBF#{names.map(&:real_search_name).join("\r\n")}"
      send_data(str, type: "text/plain",
                     charset: charset,
                     disposition: "attachment",
                     filename: "report.txt")
    end

    def render_name_list_as_csv(names)
      charset = "ISO-8859-1"
      str = CSV.generate do |csv|
        csv << %w[scientific_name authority citation accepted]
        names.each do |name|
          csv << [name.real_text_name, name.author, name.citation,
                  name.deprecated ? "" : "1"].map(&:presence)
        end
      end
      str = str.iconv(charset)
      send_data(str, type: "text/csv",
                     charset: charset,
                     header: "present",
                     disposition: "attachment",
                     filename: "report.csv")
    end

    def render_name_list_as_rtf(names)
      charset = "UTF-8"
      doc = RTF::Document.new(RTF::Font::SWISS)
      reportable_ranks = %w[Genus Species Subspecies Variety Form]
      names.each do |name|
        rank      = name.rank
        text_name = name.real_text_name
        author    = name.author
        node      = name.deprecated ? doc : doc.bold
        node      = node.italic if reportable_ranks.include?(rank)
        node << text_name
        doc << " #{author}" if author.present?
        doc.line_break
      end
      send_data(doc.to_rtf, type: "text/rtf",
                            charset: charset,
                            disposition: "attachment",
                            filename: "report.rtf")
    end
  end
end
