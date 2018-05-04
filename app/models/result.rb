require 'date'

class Result
  extend ActiveModel::Model
  include ActiveModel::Serialization

  attr_reader :id, :full_title, :volume, :issue, :publication_date, :doi

  def initialize(es_result)
    @doi = es_result['_source']['doi'].upcase
    @full_title = es_result['_source']['full_title']
    @volume = es_result['_source']['volume']
    @issue = es_result['_source']['issue']
    @publication_date = DateTime.parse(es_result['_source']['publication_date'])
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
