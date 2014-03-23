# Title: Youtube tag for Jekyll
# Authors: Devin Weaver, Daniel Roos (youtube changes)
# Description: Allows youtube tag to place videos from youtube embedded in the post.
#
# Please read my [blog post about it][2].
#
# [2]: not written yet
#
# Syntax {% youtube videocode [title] %}
#
# Examples:
# {% youtube oHg5SJYRHA0 %}
#
# Output:
# <p/>
# <center>
# <object type="application/x-shockwave-flash" data="http://www.youtube.com/v/S6xMFr85p2U" width="480" height="360"><param name="movie" value="http://www.youtube.com/v/S6xMFr85p2U" />
# <param name="FlashVars" value="playerMode=embedded" /><param name="wmode" value="transparent" />
# </object>
# </center>
# <p/>

require 'digest/md5'

module Jekyll
  
  class YoutubeTag < Liquid::Tag
    def initialize(tag_name, markup, tokens)
      # if /(?<youtubevideocode>\S+)?(?:\s+(?<title>.+))?/i =~ markup
      if /(?<youtubevideocode>\S+)/i =~ markup
        @youtubevideocode = youtubevideocode
      end
      super
    end

    def render(context)
      if @youtubevideocode
        "<p/>
<center>
<object type=\"application/x-shockwave-flash\" data=\"https://www.youtube.com/v/#{@youtubevideocode}\" width=\"480\" height=\"360\"><param name=\movie\" value=\"http://www.youtube.com/v/#{@youtubevideocode}\" />
<param name=\"FlashVars\" value=\"playerMode=embedded\" /><param name=\"wmode\" value=\"transparent\" />
</object>
</center>
<p/>"
      else
        "Error processing input, expected syntax: {% youtube videocode %}"
      end
  end
    end


end

Liquid::Template.register_tag('youtube', Jekyll::YoutubeTag)
