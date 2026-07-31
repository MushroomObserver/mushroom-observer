# frozen_string_literal: true

class FieldSlip
  module Extractor
    # Google Gemini adapter. The only place in the app that talks to
    # generativelanguage.googleapis.com -- same discipline as
    # `Inat::APIRequest` (see .claude/rules/inat_import.md), so a swap
    # to another provider is one new class beside this one.
    class Gemini
      API_BASE = "https://generativelanguage.googleapis.com/v1beta"
      # An alias rather than a pinned name: Google retires concrete
      # models out from under callers -- `gemini-2.5-flash` already
      # answers 404 with "no longer available to new users" -- and a
      # pinned default would strand the feature until someone deployed.
      # The response reports the concrete model it actually ran
      # (`modelVersion`), which is what gets stored, so provenance
      # survives the indirection. Overridable from credentials to pin a
      # specific model without a deploy.
      DEFAULT_MODEL = "gemini-flash-latest"
      # Handwriting needs the pixels; :huge is 1280px on the long edge,
      # the largest MO serves short of the untouched original.
      IMAGE_SIZE = :huge
      TIMEOUT = 60

      # `credentials.gemini` is an OrderedOptions, i.e. a Hash -- so
      # `.key` resolves to `Hash#key` and raises ArgumentError rather
      # than returning the API key. Subscript, not dot.
      def initialize(model: nil, api_key: nil)
        @model = model || credentials[:model].presence || DEFAULT_MODEL
        @api_key = api_key || credentials[:key]
      end

      def extract(image, context:)
        raise(MissingKey) if @api_key.blank?

        raw = post(Prompt.new(context).to_s, image_data(image))
        payload = parse(raw)
        Result.new(provider: "gemini",
                   model: raw["modelVersion"].presence || @model, raw: raw,
                   fields: payload["fields"] || {},
                   confidence: payload["confidence"] || {})
      end

      class MissingKey < StandardError
        def message = "No Gemini API key configured (credentials.gemini.key)"
      end

      class BadResponse < StandardError; end

      private

      def credentials
        Rails.application.credentials.gemini || {}
      end

      def post(prompt, image)
        response = RestClient::Request.execute(
          method: :post, timeout: TIMEOUT,
          url: "#{API_BASE}/models/#{@model}:generateContent",
          payload: body(prompt, image).to_json,
          headers: { content_type: :json, accept: :json,
                     "x-goog-api-key": @api_key }
        )
        JSON.parse(response.body)
      end

      def body(prompt, image)
        { contents: [{ parts: [{ text: prompt },
                               { inline_data: { mime_type: "image/jpeg",
                                                data: image } }] }],
          generationConfig: { temperature: 0,
                              response_mime_type: "application/json" } }
      end

      # Base64 of the JPEG, from disk when MO holds a copy. Production
      # writes local files before transferring them, and development's
      # image precedence puts `:local` first, so going over the network
      # for a file already on disk would be both slower and a needless
      # dependency -- this feature shouldn't need DNS to read an image
      # MO already has.
      def image_data(image)
        Base64.strict_encode64(image_bytes(image))
      end

      def image_bytes(image)
        url = image.image_url(IMAGE_SIZE)
        path = local_path(url)
        return File.binread(path) if path

        RestClient::Request.execute(method: :get, url: url.url,
                                    timeout: TIMEOUT,
                                    raw_response: true).file.read
      end

      # `Image::URL#url` resolves through `MO.image_precedence` and
      # returns the local source as a ROOT-RELATIVE path ("/images/1280/
      # 42.jpg?v") rather than a file:// URL -- the local source's
      # `read` spec is a web path, and only its `test` spec is a
      # filesystem one. So map the web prefix onto the local root rather
      # than looking for a scheme that never appears.
      def local_path(url)
        resolved = url.url.sub(/\?\d+\z/, "")
        prefix = MO.image_sources.dig(:local, :read).to_s
        return nil if prefix.blank? || !resolved.start_with?("#{prefix}/")

        path = File.join(MO.local_image_files,
                         resolved.delete_prefix("#{prefix}/"))
        File.exist?(path) ? path : nil
      end

      # The model is asked for JSON and told not to fence it, but a
      # fenced answer is the classic failure, so unwrap before parsing.
      def parse(raw)
        text = raw.dig("candidates", 0, "content", "parts", 0, "text").to_s
        JSON.parse(text.sub(/\A```(?:json)?\s*/, "").sub(/```\s*\z/, ""))
      rescue JSON::ParserError => e
        raise(BadResponse.new("Gemini did not return JSON: #{e.message}"))
      end
    end
  end
end
