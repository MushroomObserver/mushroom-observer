# frozen_string_literal: true

#
#  = API2 Inline Partials
#
#  These "inline partials" speed up tests by half an order of magnitude.
#  (High detail observations query with 1000 results went from 7.7 seconds
#  to under 2 seconds.)
#
#  NOTE: Each partial is in pairs: a JSON version and an XML version.
#  Please ensure they stay identical.
#
################################################################################

module Api2InlineHelper
  def json_api_key(api_key)
    strip_hash(id: api_key.id,
               key: api_key.key.to_s,
               notes: api_key.notes.to_s.tpl_nodiv,
               created_at: api_key.created_at.try(:utc),
               last_used: api_key.last_used.try(:utc),
               verified: api_key.verified.try(:utc),
               num_users: api_key.num_uses)
  end

  def xml_api_key(xml, api_key)
    xml_string(xml, :key, api_key.key)
    xml_html_string(xml, :notes, api_key.notes.to_s.tpl_nodiv)
    xml_datetime(xml, :created_at, api_key.created_at)
    xml_datetime(xml, :last_used, api_key.last_used)
    xml_date(xml, :verified, api_key.verified)
    xml_integer(xml, :num_users, api_key.num_uses)
  end

  def json_collection_number(collection_number)
    strip_hash(id: collection_number.id,
               collector: collection_number.name,
               number: collection_number.number)
  end

  def xml_collection_number(xml, collection_number)
    xml_string(xml, :collector, collection_number.name)
    xml_string(xml, :number, collection_number.number)
  end

  def json_comment(comment)
    strip_hash(id: comment.id,
               summary: comment.summary.to_s.tl,
               content: comment.comment.to_s.tpl_nodiv,
               created_at: comment.created_at.try(:utc),
               updated_at: comment.updated_at.try(:utc),
               owner: json_user(comment.user))
  end

  def xml_comment(xml, comment)
    xml_string(xml, :summary, comment.summary.to_s.tl)
    xml_html_string(xml, :content, comment.comment.to_s.tpl_nodiv)
    xml_datetime(xml, :created_at, comment.created_at)
    xml_datetime(xml, :updated_at, comment.updated_at)
    xml_detailed_object(xml, :owner, comment.user)
  end

  def json_external_link(external_link)
    strip_hash(id: external_link.id,
               url: external_link.url.to_s)
  end

  def xml_external_link(xml, external_link)
    xml_string(xml, :url, external_link.url)
  end

  def json_external_site(external_site)
    strip_hash(id: external_site.id,
               name: external_site.name.to_s)
  end

  def xml_external_site(xml, external_site)
    xml_string(xml, :name, external_site.name)
  end

  def json_herbarium(herbarium)
    strip_hash(id: herbarium.id,
               code: herbarium.code.to_s,
               name: herbarium.name.to_s)
  end

  def xml_herbarium(xml, herbarium)
    xml_string(xml, :code, herbarium.code)
    xml_string(xml, :name, herbarium.name)
  end

  def json_herbarium_record(herbarium_record)
    strip_hash(id: herbarium_record.id,
               accession_number: herbarium_record.accession_number.to_s,
               herbarium: json_herbarium(herbarium_record.herbarium))
  end

  def xml_herbarium_record(xml, herbarium_record)
    xml_string(xml, :accession_number, herbarium_record.accession_number)
    xml_detailed_object(xml, :herbarium, herbarium_record.herbarium)
  end

  def json_image(image)
    strip_hash(id: image.id,
               date: image.when,
               license: image.license.try(:display_name).to_s,
               notes: image.notes.to_s.tpl_nodiv,
               quality: image.vote_cache,
               owner: json_user(image.user))
  end

  def xml_image(xml, image)
    xml_date(xml, :date, image.when)
    xml_string(xml, :license, image.license.try(:display_name).to_s)
    xml_html_string(xml, :notes, image.notes.to_s.tpl_nodiv)
    xml_confidence_level(xml, :quality, image.vote_cache)
    xml_detailed_object(xml, :owner, image.user)
  end

  def json_location(location)
    strip_hash(id: location.id,
               name: location.text_name.to_s,
               latitude_north: location.north,
               latitude_south: location.south,
               longitude_east: location.east,
               longitude_west: location.west,
               altitude_maximum: location.high,
               altitude_minimum: location.low)
  end

  def xml_location(xml, location)
    xml_string(xml, :name, location.text_name)
    xml_latitude(xml, :latitude_north, location.north)
    xml_latitude(xml, :latitude_south, location.south)
    xml_longitude(xml, :longitude_east, location.east)
    xml_longitude(xml, :longitude_west, location.west)
    xml_altitude(xml, :altitude_maximum, location.high)
    xml_altitude(xml, :altitude_minimum, location.low)
  end

  def json_name(name)
    strip_hash(id: name.id,
               name: name.real_text_name.to_s,
               author: name.author.to_s,
               rank: name.rank.to_s.downcase,
               deprecated: name.deprecated ? true : false,
               misspelled: name.is_misspelling? ? true : false,
               synonym_id: name.synonym_id)
  end

  def xml_name(xml, name)
    xml_string(xml, :name, name.real_text_name)
    xml_string(xml, :author, name.author)
    xml_string(xml, :rank, name.rank.to_s.downcase)
    xml_boolean(xml, :deprecated, name.deprecated)
    xml_boolean(xml, :misspelled, name.is_misspelling?)
    xml_integer(xml, :synonym_id, name.synonym_id)
  end

  def json_naming(naming)
    strip_hash(id: naming.id,
               name: json_name(naming.name),
               owner: json_user(naming.user),
               confidence: naming.vote_cache)
  end

  def xml_naming(xml, naming)
    xml_detailed_object(xml, :name, naming.name)
    xml_detailed_object(xml, :owner, naming.user)
    xml_confidence_level(xml, :confidence, naming.vote_cache)
  end

  def json_project(project)
    strip_hash(id: project.id,
               title: project.title.to_s)
  end

  def xml_project(xml, project)
    xml_string(xml, :title, project.title)
  end

  def json_sequence(sequence)
    strip_hash(id: sequence.id,
               locus: sequence.locus.to_s,
               bases: sequence.bases.to_s,
               archive: sequence.archive.to_s,
               accession: sequence.accession.to_s)
  end

  def xml_sequence(xml, sequence)
    xml_string(xml, :locus, sequence.locus)
    xml_string(xml, :bases, sequence.bases)
    xml_string(xml, :archive, sequence.archive)
    xml_string(xml, :accession, sequence.accession)
  end

  def json_user(user)
    strip_hash(id: user.id,
               login_name: user.login.to_s,
               legal_name: user.legal_name.to_s)
  end

  def xml_user(xml, user)
    xml_string(xml, :login_name, user.login)
    xml_string(xml, :legal_name, user.legal_name)
  end

  def json_vote(vote)
    anonymous = vote.user == User.current || !vote.anonymous?
    strip_hash(id: vote.id,
               confidence: vote.value,
               naming_id: vote.naming_id,
               owner: anonymous ? json_user(vote.user) : :anonymous.l)
  end

  def xml_vote(xml, vote)
    xml_confidence_level(xml, :confidence, vote.value)
    xml_integer(xml, :naming_id, vote.naming_id)
    if vote.user == User.current || !vote.anonymous?
      xml_detailed_object(xml, :owner, vote.user)
    else
      xml_string(xml, :owner, :anonymous.l)
    end
  end

  def strip_hash(hash)
    hash.reject { |_key, val| val.blank? }
  end
end
