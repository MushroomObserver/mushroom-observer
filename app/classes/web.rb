# class with information about external websites
class Web
  # on-line primary-source repositories (Archives) for nucleotide sequences
  # in menu order
  #   name    short name, used in drop-down menu
  #   home    home page
  #   prefix  prefix for Accession (When Accession is appended to this,
  #           it will land on the page for that Accession in the Archive.)
  def self.archives
    [
      { name:   "GenBank",
        home:   "https://www.ncbi.nlm.nih.gov/genbank/",
        prefix: "https://www.ncbi.nlm.nih.gov/nuccore/" },
      { name:   "ENA",
        home:   "http://www.ebi.ac.uk/ena",
        prefix: "http://www.ebi.ac.uk/ena/data/view/" },
      { name:   "UNITE",
        home:   "https://unite.ut.ee/",
        prefix: "https://unite.ut.ee/search.php?qresult=yes&accno=" }
    ]
  end

  # return the archive hash for the named archive
  def self.archive(name)
    archives.find { |archive| archive[:name] == name }
  end

  def self.archive_home(name)
    archive(name)[:home]
  end

  def self.search_prefix(name)
    archive(name)[:prefix]
  end
end
