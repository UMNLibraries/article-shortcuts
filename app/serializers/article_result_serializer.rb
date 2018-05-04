class ArticleResultSerializer < ActiveModel::Serializer
  attributes :full_title, :volume, :issue, :article, :publication_date, :doi
end
