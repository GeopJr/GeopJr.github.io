module GeopJr
  @[YAML::Serializable::Options(emit_nulls: true)]
  class BlogPostFrontmatter
    include YAML::Serializable

    property title : String
    property subtitle : String?
    property date : Time
    property updated : Time?
    property tags : Array(String)
    property skip : Bool?
    property hidden : Bool = false
    property cover : String? = nil
    property cover_alt : String = ""
  end

  class Page::Blog::Post
    def initialize(@post : BlogPostFrontmatter, @html : String)
    end

    ECR.def_to_s "#{__DIR__}/blog_post.ecr"
  end
end
