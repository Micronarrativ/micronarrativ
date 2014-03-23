# Title: Photos tag for Jekyll
# Authors: Devin Weaver
# Licence extension: Daniel Roos (2013-01-16)
# CSS integrateion : Daniel Roos (2013-12-01)
# Description: Allows photos tag to place photos as thumbnails and open in fancybox. Uses a CDN if needed.
# Includes licenses if needed as well.
#
# ** This only covers the markup. Not the integration of FancyBox **
#
# To see an unabridged explination on integrating this with [FancyBox][1]
# Please read my [blog post about it][2].
# For information about the licensing extension [read the other blog post][3]
#
# [1]: http://fancyapps.com/fancybox/
# [2]: http://tritarget.org/blog/2012/05/07/integrating-photos-into-octopress-using-fancybox-and-plugin/
# [3]: http://blog.micronarrativ.org/blog/2013/01/16/Octopress-photos-licences
#
# Syntax {% photo filename [tumbnail] [licence:[default|<url>]][title] %}
# Syntax {% photos filename [filename] [filename] [...] %}
# If the filename has no path in it (no slashes)
# then it will prefix the `_config.yml` setting `photos_prefix` to the path.
# This allows using a CDN if desired.
#
# There are two other parameters in `_config.yml` as well worth looking at:
# `photos_default_licence`	: Defines the url to the page with the Licence information that shall be displayed when you use
#								`default` as a value in the `photos`-tag instead of an URL
# `photos_licence_icon`		: URL to the icon to use for in the bottom left corner to link to the licence information.
#								Fallback is an alt text with `[i]` that will be displayed instead.
#
# To make FancyBox work well with OctoPress You need to include the style fix.
# In your `source/_include/custom/head.html` add the following:
#
#     {% fancyboxstylefix %}
#
# Examples:
# {% photo photo1.jpg My Photo %}
# {% photo /path/to/photo.jpg %}
# {% photo /path/to/photo.jpg default licence:url/to/licence Title %}
# {% gallery %}
# photo1.jpg: my title 1
# photo2.jpg[thumnail.jpg]: my title 2
# photo3.jpg: my title 3
# {% endgallery %}
#
# Output:
# <a href="photo1.jpg" class="fancybox" title="My Photo"><img src="photo1_m.jpg" alt="My Photo" /></a>
# <a href="/path/to/photo.jpg" class="fancybox" title="My Photo"><img src="/path/to/photo_m.jpg" alt="My Photo" /></a>
# # <a href="/url/to/licence" target='_blank' style="position:relative;top:-8px;left:16px;text-decoration:none;padding:5px;" title="Licence information"><img src="./images/licence_info.png" border="0" style="border-style:none;vertical-align:text-bottom;" width="12" height="17" alt="[i]"></a><a href="/path/to/photo.jpg" class="fancybox" title="Title"><img src="/path/to/photo_m.jpg" alt="Title" /></a>
# <ul class="gallery">
#   <li><a href="photo1.jpg" class="fancybox" rel="gallery-e566c90e554eb6c157de1d5869547f7a" title="my title 1"><img src="photo1_m.jpg" alt="my title 1" /></a></li>
#   <li><a href="photo2.jpg" class="fancybox" rel="gallery-e566c90e554eb6c157de1d5869547f7a" title="my title 2"><img src="photo2_m.jpg" alt="my title 2" /></a></li>
#   <li><a href="photo3.jpg" class="fancybox" rel="gallery-e566c90e554eb6c157de1d5869547f7a" title="my title 3"><img src="photo3_m.jpg" alt="my title 3" /></a></li>
# </ul>

require 'digest/md5'

module Jekyll

  class PhotosUtil
    def initialize(context)
      @context = context
    end

    def path_for(filename)
      filename = filename.strip
      prefix = (@context.environments.first['site']['photos_prefix'] unless filename =~ /^(?:\/|http)/i) || ""
      "#{prefix}#{filename}"
    end

    # Read default licence from _config.yaml
    def path_default_licence()
      @context.environments.first['site']['photos_default_licence']
    end

    # Read path for licence information from _config.yaml
    def path_licence_info_icon()
      @context.environments.first['site']['photos_licence_icon']
    end

    def thumb_for(filename, thumb=nil)
      filename = filename.strip
      # FIXME: This seems excessive
      if filename =~ /\./
        thumb = (thumb unless thumb == 'default') || filename.gsub(/(?:_b)?\.(?<ext>[^\.]+)?$/, "_m.\\k<ext>")
      else
        thumb = (thumb unless thumb == 'default') || "#{filename}_m"
      end
      path_for(thumb)
    end
  end

  class FancyboxStylePatch < Liquid::Tag
    def render(context)
      return <<-eof
<!-- Fix FancyBox style for OctoPress -->
<style type="text/css">
  .fancybox-wrap { position: fixed !important; }
  .fancybox-opened {
    -webkit-border-radius: 4px !important;
       -moz-border-radius: 4px !important;
            border-radius: 4px !important;
  }
  .fancybox-close, .fancybox-prev span, .fancybox-next span {
    background-color: transparent !important;
    border: 0 !important;
  }
</style>
      eof
    end
  end

  class PhotoTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      if /(?<filename>\S+)(?:\s+(?<thumb>\S+))?(\slicen[sc]e[\=\:](?<licence>\S+))?(\sid[\=\:](?<cssid>\S+))?(\sform[\=\:](?<cssclass>\S+))?(?:\s+(?<title>.+))?/i =~ markup
        @filename = filename
        @thumb    = thumb
        @title    = title
        @licence  = licence
        @cssid    = cssid
        @cssclass = cssclass
      end
      super
    end

    def render(context)
      p = PhotosUtil.new(context)

      # Classes for Image formatting
      if @cssclass
        @cssidstart  = "<div class=\"#{@cssclass}\">"
        @cssidend    = '</div>' 
      end      
      
      # Special exception to center the image + license
      if @cssid == 'center'
          @cssidstart = '<center>'
          @cssidend   = '</center>'
      elsif @cssid
          @cssidstart = "<div id=\"#{@cssid}\">"
          @cssidend   = '</div>'
      end
      
      if @licence == 'default'
        @licence = p.path_default_licence
      end

      if @licence
        # CSS style for positioning the License information icon.
        @cssstyle = "class=\"imglicense\""
        @licence = "<a href=\"#{@licence}\" target='_blank' #{@cssstyle} title=\"License information\"><img src=\"#{p.path_licence_info_icon()}\" border=\"0\" style=\"border-style:none;vertical-align:text-bottom;\" width=\"12\" height=\"17\" alt=\"[i]\"></a>"
      else
        @licence = ''
      end
      if @filename
        "#{@cssidstart}<a href=\"#{p.path_for(@filename)}\" class=\"fancybox\" title=\"#{@title}\"><img src=\"#{p.thumb_for(@filename,@thumb)}\" alt=\"#{@title}\" /></a>#{@licence}#{@cssidend}"
      else
        "Error processing input, expected syntax: {% photo filename [thumbnail] [title] [licence=url] %}"
      end
    end
  end

  class GalleryTag < Liquid::Block
    def initialize(tag_name, markup, tokens)
      # No initializing needed
      super
    end

    def render(context)
      # Convert the entire content array into one large string
      content = super
      # Get a unique identifier based on content
      md5 = Digest::MD5.hexdigest(content)
      # split the text by newlines
      lines = content.split("\n")

      p = PhotosUtil.new(context)
      list = ""

      lines.each do |line|
        if /(?<filename>[^\[\]:]+)(?:\[(?<thumb>\S*)\])?(?::(?<title>.*))?/ =~ line
          list << "<li><a href=\"#{p.path_for(filename)}\" class=\"fancybox\" rel=\"gallery-#{md5}\" title=\"#{title.strip}\">"
          list << "<img src=\"#{p.thumb_for(filename,thumb)}\" alt=\"#{title.strip}\" /></a></li>"
        end
      end
      "<ul class=\"gallery\">\n#{list}\n</ul>"
    end
  end

end

Liquid::Template.register_tag('photo', Jekyll::PhotoTag)
Liquid::Template.register_tag('gallery', Jekyll::GalleryTag)
Liquid::Template.register_tag('fancyboxstylefix', Jekyll::FancyboxStylePatch)
