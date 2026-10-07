# frozen_string_literal: true

class Inat
  # Resolves whatever an admin types for a sister iNat project into the
  # one project it names (#5416). iNat identifies a project by a numeric
  # id and by a slug, and its own UI shows neither on its own, so all
  # four of these have to work:
  #
  #   2026-nama-yoop
  #   303327
  #   https://www.inaturalist.org/projects/2026-nama-yoop?tab=observations
  #   https://www.inaturalist.org/observations?project_id=303327
  #
  # Anything else is treated as a name to search for, and resolves only
  # when exactly one project comes back, or one whose title matches what
  # was typed. Refusing an ambiguous answer is the point: storing the
  # wrong project would quietly import a stranger's observations.
  class ProjectLookup
    include Inat::JsonFetch

    # Named Result, not Project: inside this class a constant named
    # Project would shadow the MO model.
    Result = Data.define(:id, :title)

    # Both `/v1/projects/:id` and the search endpoint answer for a slug,
    # but only the first one answers for an id, so it is tried first.
    PROJECT_URL_PATH = %r{/projects/([^/?#]+)}
    PROJECT_ID_PARAM = /[?&]project_id=(\d+)/
    SLUG = /\A[a-z0-9][a-z0-9-]*\z/i

    # A project's page rather than an observation search: the id or
    # slug is in the path, so there is nothing to search until it is
    # resolved. iNat's UI shows this address, so it is the one an admin
    # has to hand.
    def self.project_page?(input)
      text = input.to_s
      text.include?("://") && text.match?(PROJECT_URL_PATH)
    end

    def initialize(input)
      @input = input.to_s.strip
    end

    # The project, or nil when nothing single answers to the input.
    # `error` then holds the tag saying why, and `token` the id or slug
    # that was tried -- which is what to name in a message, since the
    # input it came out of may be a whole URL.
    attr_reader :error, :token

    def resolve
      return nil if @input.blank?

      @token = extract_token
      project = @token ? fetch(@token) : nil
      project ||= search(@input)
      @error ||= :project_site_inat_project_unknown unless project
      project
    end

    private

    # An id or slug lifted out of a URL, or the input itself when it is
    # already one. Nil when the input reads as a name to search for.
    def extract_token
      return Regexp.last_match(1) if @input.match(PROJECT_ID_PARAM)
      return Regexp.last_match(1) if @input.match(PROJECT_URL_PATH)
      return @input if @input.match?(SLUG)

      nil
    end

    def fetch(token)
      body = fetch_json("projects/#{escape(token)}")
      project_from(body&.dig("results")&.first)
    end

    # A name, or a slug iNat no longer answers to directly. One result
    # is the answer; several are only an answer when one of them is
    # titled exactly what was typed.
    def search(name)
      results = fetch_json("projects?q=#{escape(name)}&per_page=10")&.
                dig("results") || []
      return project_from(results.first) if results.one?

      exact = results.select { |r| r["title"].to_s.casecmp?(name) }
      return project_from(exact.first) if exact.one?

      @error = :project_site_inat_project_ambiguous if results.many?
      nil
    end

    def project_from(result)
      return nil if result.blank? || result["id"].blank?

      Result.new(id: result["id"].to_s, title: result["title"].to_s)
    end
  end
end
