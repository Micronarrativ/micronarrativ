# Title: Vimeo tag for Jekyll
# Authors: Devin Weaver, Daniel Roos (vimeo changes)
# Description: Allows vimeo tag to place videos from vimeo embedded in the post.
#
# Please read my [blog post about it][2].
#
# [2]: not written yet
#
# Syntax {% vimeo videcode %}
#
# Examples:
# {% vimeo 1234567 %}
#
# Output:
# <p/>
# <center>
# <div class=\"embed-video-container\"><iframe src=\"http://player.vimeo.com/video/#1234567?portrait=0&amp;color=ff9933\"></iframe>
# </object>
# </center>
# <p/>

require 'digest/md5'

module Jekyll
  
  class Vimeotag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      # if /(?<vimeovideocode>\S+)?(?:\s+(?<title>.+))?/i =~ markup
      if /(?<vimeovideocode>\S+)/i =~ markup
        @vimeovideocode = vimeovideocode
      end
      super
    end

    def render(context)
      if @vimeovideocode
        "<p/>
<center>
<div class=\"embed-video-container\"><iframe src=\"http://player.vimeo.com/video/#{@vimeovideocode}?portrait=0&amp;color=ff9933\"></iframe>
</center>
<p/>"
      else
        "Error processing input, expected syntax: {% vimeo videocode %}"
      end
  end
    end


end

Liquid::Template.register_tag('vimeo', Jekyll::Vimeotag)
