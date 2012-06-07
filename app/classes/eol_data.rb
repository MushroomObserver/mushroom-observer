# encoding: utf-8
#
#  = EOL Data
#
#    name_count
#    total_image_count
#    total_description_count
#    has_images?(id) - id is the id of a Name
#    images(id) - id is the id of a Name
#    image_count(id) - id is the id of a Name
#    has_descriptions?(id) - id is the id of a Name
#    descriptions(id) - id is the id of a Name
#    description_count(id) - id is the id of a Name
#
################################################################################

class EolData
  attr_accessor :names
  
  def initialize
    self.names = prune_synonyms(image_names() + description_names())
    @id_to_image = id_to_image()
    @name_id_to_images = name_id_to_images()
    @id_to_description = id_to_description()
    @name_id_to_descriptions = name_id_to_descriptions()
    @license_id_to_url = license_id_to_url()
    @user_id_to_legal_name = user_id_to_legal_name()
    @description_id_to_authors = description_id_to_authors()
   end
      
  def name_count
    self.names.count
  end
  
  def total_image_count
    @id_to_image.count
  end
  
  def total_description_count
    @id_to_description.count
  end
  
  def has_images?(id)
    @name_id_to_images.member?(id)
  end

  def all_images
    @id_to_image.values
  end
  
  def images(id)
    @name_id_to_images[id]
  end
  
  def image_count(id)
    if self.has_images?(id)
      @name_id_to_images[id].count
    else
      0
    end
  end
  
  def has_descriptions?(id)
    @name_id_to_descriptions.member?(id)
  end
  
  def all_descriptions
    @id_to_description.values
  end
  
  def descriptions(id)
    @name_id_to_descriptions[id]
  end
  
  def description_count(id)
    if self.has_descriptions?(id)
      @name_id_to_descriptions[id].count
    else
      0
    end
  end

  def license_url(id)
    @license_id_to_url[id]
  end
  
  def legal_name(id)
    @user_id_to_legal_name[id]
  end
  
  def authors(id)
    @description_id_to_authors[id].join(', ')
  end
  
private    
  def prune_synonyms(names)
    synonyms = Hash.new{|h, k| h[k] = []}
    for n in names
      if n.synonym_id
        synonyms[n.synonym_id] << n
      end
    end
    names_to_keep = []
    synonyms.each {|s| names_to_keep.push(most_desirable_name(s[1]))}
    names.delete_if {|n| n.synonym_id and not names_to_keep.member?(n)}
    names
  end

  def most_desirable_name(names)
    most_desirable = names[0]
    for new_name in names[1..-1]
      most_desirable = most_desirable.more_popular(new_name)
    end
    most_desirable
  end

  DESCRIPTION_CONDITIONS = %(FROM name_descriptions, names
    WHERE name_descriptions.name_id = names.id
    AND names.ok_for_export
    AND NOT names.deprecated
    AND name_descriptions.review_status in ('vetted', 'unvetted')
    AND name_descriptions.ok_for_export
    AND name_descriptions.public
  )
  
  def description_names
    return get_sorted_names(DESCRIPTION_CONDITIONS)
  end

  def name_id_to_descriptions
    descriptions = @id_to_description
    make_list_hash_from_pairs(Name.connection.select_all("SELECT DISTINCT names.id nid, name_descriptions.id did #{DESCRIPTION_CONDITIONS}").map{
      |row| [row['nid'], descriptions[row['did']]]
    })
  end
  
  def id_to_description
    return make_id_hash(NameDescription.find_by_sql("SELECT DISTINCT name_descriptions.* #{DESCRIPTION_CONDITIONS}"))
  end

  IMAGE_CONDITIONS = %(FROM observations, images_observations, images, names
    WHERE observations.name_id = names.id
    AND observations.vote_cache >= 2.4
    AND observations.id = images_observations.observation_id
    AND images_observations.image_id = images.id
    AND images.vote_cache >= 2
    AND images.ok_for_export
    AND names.ok_for_export
    AND NOT names.deprecated
    AND names.rank IN ('Form','Variety','Subspecies','Species', 'Genus')
  )

  def image_names
    get_sorted_names(IMAGE_CONDITIONS)
  end

  def get_sorted_names(conditions)
    SortedSet.new(Name.find_by_sql("SELECT DISTINCT names.* #{conditions}"))
  end

  def name_id_to_images
    make_list_hash_from_pairs(Name.connection.select_all("SELECT DISTINCT names.id nid, images.id iid #{IMAGE_CONDITIONS}").map{
      |row| [row['nid'], @id_to_image[row['iid']]]
    })
  end
  
  def id_to_image
    make_id_hash(Image.find_by_sql("SELECT DISTINCT images.* #{IMAGE_CONDITIONS}"))
  end
  
  def license_id_to_url()
    # There are only three licenses at the moment. Just grabbing them all.
    result = {}
    License.find(:all).each {|l| result[l.id] = l.url}
    result
  end
  
  def user_id_to_legal_name()
    # Just grab the ones with contribution > 0 (1621) since we're going to use at least 400 of them
    result = {}
    User.find(:all, :conditions => "contribution > 0").each {|o| result[o.id] = o.legal_name }
    result
  end
  
  def description_id_to_authors()
    result = make_list_hash_from_pairs(Name.connection.select_all("SELECT * FROM name_descriptions_authors").map{
      |row| [row['name_descriptions_id'].to_i, @user_id_to_legal_name[row['user_id'].to_i]]
    })
    all_descriptions.each {|d| result[d.id] = [@user_id_to_legal_name[d.user_id]] if !result.member?(d.id)}
    result
  end
  
  def make_list_hash_from_pairs(pairs)
    result = Hash.new{|h, k| h[k] = []}
    for x, y in pairs
      result[x].push(y)
    end
    result
  end
  
  def make_id_hash(obj_list)
    result = {}
    obj_list.each {|o| result[o.id] = o}
    result
  end
end