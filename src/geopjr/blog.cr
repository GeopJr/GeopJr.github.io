module GeopJr
  class BlogPostEntry
    class BlogRenderer < Markd::HTMLRenderer
      HEADINGS.map_with_index!(2) do |h, i|
        h = "h#{i}"
      end
      HEADINGS[-1] = HEADINGS[-2]
    end

    class Youtube
      include JSON::Serializable

      property id : String
      property time : String?
      property title : String?
    end

    getter filename : String
    getter fm : BlogPostFrontmatter

    @io_pos_content : Int32 | Int64

    def initialize(@filename : String, @fm : BlogPostFrontmatter, @io : IO)
      @io_pos_content = @io.pos
    end

    private def figure(title : String?, content : String)
      return content if title.nil?

      <<-HTML
      <figure>
        #{content}
        <figcaption>#{title}</figcaption>
      </figure>
      HTML
    end

    private def image(url : String, alt : String = "")
      <<-HTML
        <img alt="#{alt}" src="#{url}" />
      HTML
    end

    def self.remove_tags(content : String) : String
      content.gsub(/<[^>]*>/, "").gsub("\n", " ").gsub("  ", " ")
    end

    # Turns <youtube> custom elements into
    # an anchor with its thumbnail
    private def youtube(content : String) : String
      res = content
      res.scan(/^#youtube +(\{.+\})$/mi) do |m|
        youtube_obj = Youtube.from_json(m[-1])
        tag = <<-HTML
          <a title="Watch on YouTube" class="youtube" href="https://www.youtube.com/watch?v=#{youtube_obj.id}#{youtube_obj.time.nil? ? nil : "&t=#{youtube_obj.time}"}">
            #{figure(youtube_obj.title, image("https://img.youtube.com/vi/#{youtube_obj.id}/mqdefault.jpg"))}
          </a>
        HTML
        res = res.sub(m[0], tag)
      end
      res
    end

    private def note(content : String) : String
      res = content
      res.scan(/(^|\n)::: ?(?<title>.+)\n(?<content>(.|\n)+)\n:::(\n|$)/i) do |m|
        tag = <<-HTML

          <article class="info-box">
            <p class="title">#{m["title"]}</p>
            <p class="content">#{m["content"]}</p>
          </article>

        HTML
        res = res.sub(m[0], tag)
      end
      res
    end

    @@markd_options = Markd::Options.new
    @@markd_formatter = Tartrazine::Html.new(
      theme: Tartrazine.theme("gruvbox"),
      line_numbers: true,
      standalone: false,
    )
    def to_html : String
      @io.seek(@io_pos_content, IO::Seek::Set) if @io.pos != @io_pos_content

      post_source = @io.gets_to_end
      post_source = note(youtube(post_source))
      template = Crustache.parse post_source
      processed_source = Crustache.render template, {
        "GEOPJR_BLOG_ASSETS" => "/assets/images/blog/#{@filename}",
        "GEOPJR_EXT"         => GeopJr::CONFIG.ext,
      }.merge(GeopJr::CONFIG.emotes)
      return "" if processed_source.empty?

      BlogRenderer.new(@@markd_options).render(Markd::Parser.parse(processed_source, @@markd_options), @@markd_formatter)
    end
  end

  class Blog
    def initialize(@blog_path : Path)
    end

    # Splits a blog post with frontmatter
    # into BlogPostFrontmatter and frontmatter unparsed
    private def frontmatter(io : IO) : BlogPostFrontmatter
      fm = IO::Delimited.new(io, "\n---").gets_to_end
      BlogPostFrontmatter.from_yaml(fm)
    end

    def generate_blog_posts : Array(BlogPostEntry)
      res = [] of BlogPostEntry
      Dir.each_child(@blog_path) do |post|
        next if post.starts_with?("_")

        post_path = @blog_path / post
        post_source = File.open(post_path)
        file_domain = post_path.basename(".md")

        fm = frontmatter(post_source)
        next if fm.skip == true

        res << BlogPostEntry.new(file_domain, fm, post_source)
      end

      res
    end

    def self.write_blog_posts
      blog_navbar = Layout::Navbar.new("blog").to_s
      blog_post_footer_icon = FooterIcon.new
      blog_post_footer_image = FooterImage.new

      BLOG_POSTS.each do |v|
        html = v.to_html
        File.write(
          GeopJr::CONFIG.paths[:out] / "blog" / "#{v.filename}.html",
          Layout::Page.new(
            Page::Blog::Post.new(v.fm, html).to_s,
            blog_navbar,
            Layout::Footer.new(blog_post_footer_icon.next_icon, blog_post_footer_image.next_image).to_s,
            GeopJr::Tags.new(
              v.fm.title,
              "#{v.fm.subtitle.nil? ? nil : "#{v.fm.subtitle} - "}#{BlogPostEntry.remove_tags(html)[0..100]}...",
              "blog/#{v.filename}",
              Styles[:blog_post],
              cover: v.fm.cover.nil? ? nil : {v.fm.cover.not_nil!, v.fm.cover_alt}
            )
          ).to_s
        )
      end
    end
  end
end
