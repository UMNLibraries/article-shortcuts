class Result
  extend ActiveModel::Model
  include ActiveModel::Serialization

  attr_reader :id, :full_title, :volume, :issue, :doi

  def initialize(es_result)
    @doi = es_result['_source']['doi'].upcase
    @full_title = es_result['_source']['full_title']
    @volume = es_result['_source']['volume']
    @issue = es_result['_source']['issue']
  end

  # JSON:API requires an id, or the serializer will only return one record
  def id
    @doi
  end

  #def cache_key; @doi; end

  def persisted?
    false
  end
end
