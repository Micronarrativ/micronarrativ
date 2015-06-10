#
# Simple git log extractor for the latest updates
# Author: Daniel Roos
# Description: Fetches subject, date and note from the git log when it involved
#   updates or changes on the posting of a jekyll blog post
#
# == Parameter
#
# path:
#
# path to the directory of changes to include. Default: _path
#
#
# since:
#
# Date of since when to include changes. Default: 1970-01-01
#
#
# limit:
#
# Integer with maximum number of changes to include. Default: 10
# If set to 0 all changes are included.
#
#
# == Syntax
#
# {% gitupdates [path:postdirectory] [since:YYYY-MM-DD] [limit:<number> %}
#
# == Example
#
# {% gitupdates path:_posts since:2015-01-01 limit:10 %]
#
# == Output
#
# <html>
# * **YYYY-MM-DD**, GITSubject 
#     note
#
module Jekyll

  # TODO: Allow multiple directories to include pages as well
   
  class Gitupdates < Liquid::Tag
    @@directory  = ''
    @@since      = ''
    @@limit      = '10'

    def initialize(tag_name, markup, tokens)
      puts 'Running gitupdates'
      markup.split(' ').each do |value|
       case value
       when /^path/
         tmp, @@directory  = value.split(':')
       when /^since/
         tmp, @@since      = value.split(':')
       when /^limit/
         tmp, @@limit      = value.split(':')
       else
         puts "Unknown parameter in tag 'gitupdates': #{value}. Abort."
         exit 1
       end
      end
      super
    end

    def render(context)
      output = super

      param_directory = (@@directory == '') ? ' _posts' : @@directory
      param_number  = (@@limit == 0) ? '' : " -n #{@@limit}"
      param_date    =  (@@since == '') ? '' : " --since #{@@since}"

     # Fetch the log from git
     gitlog = `git log #{param_number} --since 2015-01-01 --notes --pretty='%ad;%s;%b' --date=short #{param_directory}`
     
     # Iterate thouch all loglines
     gitupdates = Array.new 
     gitlog.each_line do |line|

       # Skip empty lines (may happen)
       line.match(/^$/) ? next : ''

       date,subject,note = line.split(';')
       note = !note.nil? ?  "  \n  #{note}" : ''.chomp
       gitupdates << "* **#{date}**, #{subject}#{note}"

     end

      gitupdates.join
    end

  end

end

Liquid::Template.register_tag('gitupdates', Jekyll::Gitupdates)
