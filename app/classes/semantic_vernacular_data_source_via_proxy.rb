# encoding: utf-8
#
#  = Semantic Vernacular Data Source
#
#  This class describes Semantic Vernacular data model.
#
#  == Class Methods
#
#  update_contribution::    Callback that keeps User contribution up to date.
#
#  == Instance Methods
#  ==== Public
#  get_site_data::           Returns stats for entire site.
#  ==== Private
#  load_user_data::          Populates @user_data.
#
#  == Internal Data Structure
#
#  The private method load_user_data caches its information in the instance
#  variable +@user_data+.  Its structure is as follows:
#
#    @user_data = {
#      user.id => {
#        :id         => user.id,
#        :name       => user.unique_text_name,
#        :bonuses    => user.sum_bonuses,
#        :<category> => <num_records_in_category>,
#        :metric     => <weighted_sum_of_category_counts>,
#      },
#    }
#
################################################################################

class SemanticVernacularDataSourceViaProxy < SemanticVernacularDataSource
	private
	
	RPI_SPARQLPROXY = "http://logd.tw.rpi.edu/ws/sparqlproxy.php"
	QUERY_OUTPUT_FORMAT = "exhibit"	# json

	def self.query(query)
		url = URI.parse(
						RPI_SPARQLPROXY + 
						"?query=" + URI.encode_www_form_component(query) + 
						"&service-uri=" + URI.encode_www_form_component(ENDPOINT) + 
						"&output=" + URI.encode_www_form_component(QUERY_OUTPUT_FORMAT)
					)
		http = Net::HTTP.new(url.host, url.port)
		request = Net::HTTP::Get.new(url.request_uri)
		response = JSON.parse(http.request(request).body)["items"]
	end
end