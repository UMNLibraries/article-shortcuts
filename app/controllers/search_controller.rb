require 'simple_doi'
class SearchController < ApplicationController
  def search
    if params[:q]
      if doi(params[:q])
        result = es.get index: 'article', type: 'article', id: @doi.to_s.upcase
        article_result = ArticleResult.new result
        render json: article_result
      else
        # full search
        result = es.search index: 'article', body: es_query(params[:q])
        article_results = result['hits']['hits'].map { |r| ArticleResult.new r }
        # raise ars.inspect
        render json: article_results #, each_serializer: ArticleResultSerializer}
      end
    end
  end

  protected
  # Returns a SimpleDOI::DOI if one is found in the input string
  def doi(search)
    ext = SimpleDOI.extract(search)
    @doi = !ext.empty? ? ext.first : nil
  end

  def es
    # reads ENV['ELASTICSEARCH_URL'] or localhost:9200
    @es ||= Elasticsearch::Client.new
  end

  def es_query(search)
    {
      query: {
        bool: { 
          should: [
            {match: {
              'article.title' => {query: search, operator: 'and', boost: 2}
            }},
            {
              nested: {
                path: 'article.authors',
                query: {
                  match: {
                    'article.authors.name.surname' => {query: search}
                  }
                }
              }
            }
          ]
        }
      }
    }
  end
end
