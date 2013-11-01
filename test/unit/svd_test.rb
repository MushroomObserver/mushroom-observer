# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class SvdTest < UnitTestCase
  def name_counts(svds)
    with_name = 0
    without_name = 0
    svds.each {|svd|
      if svd.name
        with_name += 1
      else
        without_name += 1
      end
    }
    [with_name, without_name]
  end
  
  def test_all_svds
    begin
      results = Svd.all_svds
      with_name, without_name = name_counts(results)
      assert(with_name > 0)
      assert(without_name > 0)
      svd = results[0]
      assert(svd.uri)
    rescue Errno::EHOSTUNREACH => err
    end
  end
end
