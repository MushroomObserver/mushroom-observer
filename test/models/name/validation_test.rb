# frozen_string_literal: true

require("test_helper")

# Tests for Name::Validation (app/models/name/validation.rb)
class Name::ValidationTest < UnitTestCase
  def test_user_validation
    params = {
      text_name: "Whoosia whatsitii",
      author: "Blah & de Blah",
      search_name: "Whoosia whatsitii Blah & de Blah",
      display_name: "__Whoosia__ __whatsitii__ Blah & de Blah",
      deprecated: true,
      rank: "Species"
    }
    assert_nil(Name.create(params).id)
    assert_not_nil(Name.create(params.merge(user: rolf)).id)

    # `current_user` also satisfies the validation when no explicit
    # `user:` is present. Distinct text_name from the params above to
    # avoid tripping search_name_indistinct instead.
    other_params = params.merge(
      text_name: "Whoosia otherii",
      search_name: "Whoosia otherii Blah & de Blah",
      display_name: "__Whoosia__ __otherii__ Blah & de Blah"
    )
    name = Name.new(other_params)
    name.current_user = rolf
    assert(name.valid?, "current_user should satisfy user_presence")
  end

  def test_name_field_size_limits
    # text_name_limit(100) + author_limit(100) + 4
    assert_equal(204, Name.search_name_limit)
    # text_name_limit(100) + author_limit(100) + 21
    assert_equal(221, Name.sort_name_limit)
    # text_name_limit(100) + author_limit(100) + 41
    assert_equal(241, Name.display_name_limit)
  end

  def test_text_name_length_validation
    long_text_name = "X" * (Name.text_name_limit + 1)
    name = Name.new(
      user: users(:rolf),
      text_name: long_text_name, author: "", rank: "Genus",
      search_name: long_text_name,
      display_name: "**__#{long_text_name}__**",
      sort_name: long_text_name
    )
    assert(name.invalid?,
           "Name with text_name over the limit should be invalid")
    assert(name.errors[:text_name].any?,
           "Overlong text_name should add a :text_name error")
  end

  def test_author_length_validation
    long_author = "X" * (Name.author_limit + 1)
    name = Name.new(
      user: users(:rolf),
      text_name: "Paradiscina", author: long_author, rank: "Genus",
      search_name: "Paradiscina #{long_author}",
      display_name: "**__Paradiscina__** #{long_author}",
      sort_name: "Paradiscina  #{long_author}"
    )
    assert(name.invalid?,
           "Name with author over the limit should be invalid")
    assert(name.errors[:author].any?,
           "Overlong author should add an :author error")
  end

  def test_author_allowed_characters
    # Start with valid Name params, author has only letters,
    # using params which are different from fixtures to avoid conflict.
    valid_params = {
      user: users(:rolf),
      text_name: "Paradiscina", author: "Benedix", rank: "Genus",
      search_name: "Paradiscina Benedix",
      display_name: "**__Paradiscina__** Benedix",
      sort_name: "Paradiscina  Benedix"
    }
    assert(Name.new(valid_params).valid?,
           "Letters should be allowable in Author")
    # ----- modify Author to prove validity of other characters
    # A period can be part of an abbreviated Author
    assert(Name.new(valid_params.merge({ author: "Benedix." })).valid?,
           "Period should be allowable in Author")
    # Contrived example to test spaces
    assert(Name.new(valid_params.merge({ author: "Benedix Benedix" })).valid?,
           "Space should be allowable in Author")
    # Parens can enclose author(s) of basionym
    assert(Name.new(valid_params.merge({ author: "(Benedix) Benedix" })).valid?,
           "Parens should be allowable in Author")
    # Ampersand can appear when there are multiple authors
    assert(Name.new(valid_params.merge({ author: "Benedix & Woo" })).valid?,
           "Ampersand should be allowable in Author")
    assert(Name.new(valid_params.merge({ author: "Ben-edix" })).valid?,
           "Hyphen should be allowable in Author")
    # Commas can separate multiple authors
    assert(Name.new(valid_params.merge({ author: "Benedix, Woo & Zhu" })).
      valid?, "Commas should be allowable in Author")
    assert(Name.new(valid_params.merge({ author: "B'enedix" })).
      valid?, "Single quote should be allowable in Author")
    # MycoBank allows square brackets in author to show correction. Ex:
    # Xylaria symploci Pande, Waingankar, Punekar & Ran[a]dive
    # https://www.mycobank.org/page/Name%20details%20page/field/Mycobank%20%23/585173
    assert(Name.new(valid_params.merge({ author: "Ben[e]dix" })).valid?,
           "Square brackets should be allowable in Author")
    author = "V. Kučera".unicode_normalize
    assert(Name.new(valid_params.merge({ author: author })).valid?,
           "Composed Unicode chars should be allowable in author")
    author = "V. Kučera".unicode_normalize(:nfd)
    assert(Name.new(valid_params.merge({ author: author })).valid?,
           "author with uncomposed Unicode chars should pass validation")
    # ----- Prove that including bad character prevents validation of Name
    # Users have added numbers manually
    # or pasted an IF or MB line into the Name form
    assert(Name.new(valid_params.merge({ author: "Benedix (1969)" })).
      invalid?, "Numerals should not be allowable in Author")
    # Users have added brackets by pasting IF or MB line into the Name form
    # Hasn't happened yet; but waiting for ExcitedDelirium to drop the shoe
    assert(Name.new(valid_params.merge({ author: "Benedix 🤮" })).
      invalid?, "Emoji should not be allowable in Author")
  end

  # Prove which characters that are allowed in author
  # are allowed/disallowed at end
  def test_author_allowed_ending
    # Start with valid Name params, author ending in letter,
    # using params distinct from fixtures to avoid conflict.
    valid_params = {
      user: users(:rolf),
      text_name: "Paradiscina", author: "Benedix", rank: "Genus",
      search_name: "Paradiscina Benedix",
      display_name: "**__Paradiscina__** Benedix",
      sort_name: "Paradiscina  Benedix"
    }
    assert(Name.new(valid_params).valid?,
           "Author ending in letter should be validated")
    author = "Lizoň".unicode_normalize
    assert(Name.new(valid_params.merge({ author: author })).valid?,
           "Author ending in composed unicode char should pass validation")
    author = "Lizoň".unicode_normalize(:nfd)
    assert(Name.new(valid_params.merge({ author: author })).valid?,
           "Author ending in uncomposed unicode char should pass validation")

    assert(Name.new(valid_params.merge({ author: "Benedix." })).valid?,
           "Period at end of author should be allowable")

    # Some actually occuring cases of bad endings
    # Emulate user pasting certain IF lines into the Name form
    assert(
      Name.new(valid_params.merge({ author: "Benedix," })).
      invalid?, "Comma at end of author should not be allowable"
    )
    assert(
      Name.new(valid_params.merge({ author: "Benedix [as 'Paradiscena']" })).
      invalid?, "Square bracket at end of author should not be allowable"
    )
  end

  def test_search_name_trivial_differences
    name = names(:lactarius_subalpinus)
    assert_not(name.author.ascii_only?,
               "Test needs fixture whose Author has non-ASCII characters")
    name_params = {
      text_name: name.text_name,
      author: name.author,
      display_name: name.display_name,
      search_name: name.search_name,
      user: name.user
    }

    new_name = Name.new(
      name_params.merge(author: I18n.transliterate(name.author),
                        search_name: I18n.transliterate(name.search_name))
    )

    assert(new_name.invalid?,
           "Name differing only in diacriticals should be invalid")
    assert(
      new_name.errors[:search_name].any?,
      "Name differing only in diacriticals should create error on :search_name"
    )

    new_name = Name.new(
      name_params.merge(author: "#{name.author},",
                        search_name: "#{name.search_name},")
    )

    assert(new_name.invalid?,
           "Name differing only in punctuation should be invalid")
    assert(
      new_name.errors[:search_name].any?,
      "Name differing only in punctuation should create error on :search_name"
    )
  end

  def test_search_name_blank
    name = names(:lactarius_subalpinus)
    assert_not(name.update(search_name: ""))
  end
end
