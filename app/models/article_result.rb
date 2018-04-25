class ArticleResult < Result
  attr_reader :article

  def initialize(args)
    super
    @article = args['_source']['article']
  end

end
