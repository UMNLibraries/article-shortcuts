require 'simple_doi'
require 'anystyle'

class SearchController < ApplicationController
  def search
    if params[:q]
      @dois = doi(params[:q])
      # Query by list of extracted DOIs or by normal search
      es_body = @dois.empty? ? es_query(params[:q]) : es_by_dois(@dois)
      result = es.search index: 'article', body: es_body
      article_results = result['hits']['hits'].map { |r| ArticleResult.new r }
      render json: article_results
    end
  end

  protected
  # Returns a SimpleDOI::DOI if one is found in the input string
  def doi(search)
    SimpleDOI.extract(search).map { |d| d.to_s.upcase }
  end

  def es
    # reads ENV['ELASTICSEARCH_URL'] or localhost:9200
    @es ||= Elasticsearch::Client.new
  end

  def es_by_dois(dois)
    {
      query: {
        ids: {
          type: 'article', values: dois
        }
      }
    }
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
