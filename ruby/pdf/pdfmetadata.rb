#!/usr/bin/env ruby
# 20141126/JT
#
# Version 0.9
# - Added 'rename' option to edit metatags
# - Fixed some output strings
#
# Version 0.x
# - All other stuff
#
# Check and set metadata of PDF documents
# 
# A complete set of metada contains
#
# * CreateDate
# * Title
# * Author
# * Creator (optional)
# * Subject
# * Keywords (optional)
#
# TODO: Include password protected PDF documents as well
# TODO: Fix broken PDF files automatically
# gs \
#   -o repaired.pdf \
#   -sDEVICE=pdfwrite \
#   -dPDFSETTINGS=/prepress \
#   corrupted.pdf
#
require "thor"
require "highline/import"
require "fileutils"
require "i18n"

#
# Function to read the metadata from a given file
# hash readMetadata(string)
#
def readMetadata(pathFile = false) 
  metadata = Hash.new 
  metadata['keywords']    = ''
  metadata['subject']     = ''
  metadata['title']       = ''
  metadata['author']      = ''
  metadata['creator']     = ''
  metadata['createdate']  = ''
  if not File.file?(pathFile)
    puts "Cannot access file #{pathFile}. Abort"
    abort
  end

  # Fetch the Metada with the help of exiftools (unless something better is
  # found
  metaStrings = `exiftool '#{pathFile}' | egrep -i '^Creator\s+\:|^Author|Create Date|Subject|Keywords|Title'`

  # Time to cherrypick the available data
  entries = metaStrings.split("\n")
  entries.each do |entry|
    values = entry.split(" : ")
    values[0].match(/Creator/) and metadata['creator'] == '' ? metadata['creator'] = values[1]: metadata['creator'] = ''
    values[0].match(/Author/) and metadata['author'] == '' ? metadata['author'] = values[1]: metadata['author'] = ''
    values[0].match(/Create Date/) and metadata['createdate'] == '' ? metadata['createdate'] = values[1]: metadata['createdate'] = ''
    values[0].match(/Subject/) and metadata['subject'] == '' ? metadata['subject'] = values[1]: metadata['subject'] = ''
    values[0].match(/Keywords/) and metadata['keywords'] == '' ? metadata['keywords'] = values[1]: metadata['keywords'] =''
    values[0].match(/Title/) and metadata['title'] == '' ? metadata['title'] = values[1]: metadata['title'] =''
  end
  return metadata
end

#
# Set Keywords Preface based on title and subject
# If subject matches a number/character combination and contains no spaces,
# the preface will be combined with the doktype.
# If not: preface will contain the whole subject with dots and spaces being
# replaced with underscores
#
def setKeywordsPreface(metadata, doktype)
  if metadata['subject'].match(/^\d+[^+s]+.*/)
    return doktype + metadata['subject']
  else
    #return metadata['subject'].gsub(/\ø/,'oe').gsub(/[^a-zA-Z0-9]+/,'_')
    #subject = metadata['subject'].chars.normalize
    subject = metadata['subject']

    # Take care of special characters
    I18n.enforce_available_locales = false
    subject = I18n.transliterate(metadata['subject'])

    # Replace everything else
    subject = subject.gsub(/[^a-zA-Z0-9]+/,'_')
    return subject
  end
end

#
# Read user input
#
def readUserInput(textstring = 'Enter value: ')
  return ask textstring
end

#
# Identify a date
# Function takes a string and tries to identify a date in there.
# returns false if no date could be identified
# otherwise the date is returned in the format as
#
#   YYYY:MM:DD HH:mm:ss
#
# For missing time values zero is assumed
#
def identifyDate(datestring)
  identifiedDate = ''
  year    = '[1-2][90][0-9][0-9]'
  month   = '0[0-9]|10|11|12'
  day     = '[1-9]|0[1-9]|1[0-9]|2[0-9]|3[0-1]'
  hour    = '[0-1][0-9]|2[0-3]|[1-9]'
  minute  = '[0-5][0-9]'
  second  = '[0-5][0-9]'
  case datestring
  when /^(#{year})(#{month})(#{day})$/
    identifiedDate =  $1 + ':' + $2 + ':' + $3 + ' 00:00:00'
  when /^(#{year})(#{month})(#{day})(#{hour})(#{minute})(#{second})$/
    identifiedDate =  $1 + ':' + $2 + ':' + $3 + ' ' + $4 + ':' + $5 + ':' + $6
  when /^(#{year})[\:|\.|\-](#{month})[\:|\.|\-](#{day})\s(#{hour})[\:](#{minute})[\:](#{second})$/
    identifiedDate =  $1 + ':' + $2 + ':' + $3 + ' ' + $4 + ':' + $5 + ':' + $6
  when /^(#{year})[\:|\.|\-](#{month})[\:|\.|\-](#{day})$/
    day   = "%02d" % $3
    month = "%02d" % $2
    identifiedDate =  $1 + ':' + month + ':' + day + ' 00:00:00'
  else
    identifiedDate = false
  end
  return identifiedDate
end

class DOC < Thor

  #
  # Show the current metadata tags
  #
  # TODO: format output as JSON and YAML
  #
  desc 'show', 'Show metadata of a file'
  method_option :all, :type => :boolean, :aliases => '-a', :desc => 'Show all metatags', :default => false, :required => false
  method_option :tag, :type => :string, :aliases => '-t', :desc => 'Show specific tag', :required => false
  long_desc <<-LONGDESC
  `CLI show -t TAG <filename> ` will show the tag(s) 'TAG'

  >CLI show -t author example.pdf
  John Doe

  >CLI show -t author,title example.pdf
  John Doe
  Example Document

  # Options
  -a|--all      Show all Metatags that are managed.
  -t|--tag      List tags do show, separated by comma. Each tag will be output
                in a separate line.

  LONGDESC
  def show(filename)
    metadata = readMetadata(filename)

    # Output all metatags
    if options[:all] or options[:tag].nil?
      puts "Author      : " + metadata['author']
      puts "Creator     : " + metadata['creator']
      puts "CreateDate  : " + metadata['createdate']
      puts "Subject     : " + metadata['subject']
      puts "Title       : " + metadata['title']
      puts "Keywords    : " + metadata['keywords']

    # Ouput only specific tags
    elsif not options[:tag].nil?

      tags = options[:tag].split(',')
      tags.each do |tag|
        puts metadata[tag]
      end
    end

  end

  #
  # Change a MetaTag Attribute
  #
  # TODO: keywords are added differently according to the documentation
  # http://www.sno.phy.queensu.ca/~phil/exiftool/faq.html
  desc 'edit', 'Edit Meta Tag'
  long_desc <<-LONGDESC
  `CLI edit -t TAG <filename> ` will edit the tag 'TAG' and set the new value.

  >CLI edit -t author example.pdf
  ...some fancy IO
  ...done

  LONGDESC
  method_option :tag, :type => :string, :aliases => '-t', :desc => 'Name of the Tag to Edit', :default => false, :required => true
  method_option :rename, :type => :boolean, :aliases => '-r', :desc => 'Rename file after changing meta-tags', :default => false, :required => false
  def edit(filename)
    metadata = readMetadata(filename)

    if options[:tag] == 'all'
      tags = ['author','title','subject','createdate','keywords']
    else
      tags = options[:tag].split(',')
    end
    tags.each do |currentTag|
      # Change the tag to something we can use here
      answer   = readUserInput("Enter new value for #{currentTag} :")
      if currentTag == 'createdate'
        while not answer = identifyDate(answer)
          puts 'Invalid date format'
          answer = readUserInput("Enter new value for #{currentTag} :")
        end
      end
      puts "Changing value for #{currentTag}: #{metadata[currentTag]} => #{answer}"
      `exiftool -#{currentTag}='#{answer}' -overwrite_original '#{filename}'`
    end

    puts `#{__FILE__} rename '#{filename}'`

    #
    # If required, run the renaming task afterwards
    # This is not pretty, but seems to be the only way to do this in THOR
    #
    if options[:rename]
      puts `#{__FILE__} rename '#{filename}'`
    end

  end

  #
  # Check the metadata for the minium necessary tags
  # See documentation at the top of this file for defailts
  #
  # void check(string)
  desc 'check', 'Check Metadata for completeness'
  def check(filename)
    returnvalue = 0
    readMetadata(filename).each do|key,value|
      if key.match(/author|subject|createdate|title/) and value.empty?
        puts 'Missing value: ' + key 
        returnvalue == 0 ? returnvalue = 1 : ''
      end
    end
    exit returnvalue
  end

  #
  # Explain fields and Metatags
  # Show information about how they are used.
  #
  desc 'explain','Show more information about usuable Meta-Tags'
  def explain(tag)
    # TODO: THis thingy

  end

  #
  # Rename the file according to the Metadata
  #
  # Scheme: YYYYMMDD-author-subject-keywords.extension
  desc 'rename', 'Rename the file according to Metadata'
  long_desc <<-LONGDESC
  `CLI rename <filename>` will rename the file to the metatags accordingly

  # Example PDF with following MetaTags:
  #
  # Filename: example.pdf
  # Author: John
  # Subject: new Product
  # Title: Presentation
  # CreateDate: 1970:01:01 01:00:00
  # Keywords: John Doe, Jane Doe, Mister Doe

  # Renaming the file
  >CLI rename example.pdf
  example.pdf => 19700101-john-dok-new_product-john_doe-jane_doe.pdf

  # Simulation to rename the file (no actual change)
  > CLI rename -n example.pdf
  example.pdf => 19700101-john-dok-new_product-john_doe-jane_doe.pdf

  # Renaming the file with all keywords
  > CLI rename -n -a example.pdf
  example.pdf => 19700101-john-dok-new_product-john_doe-jane_doe-mister_doe.pdf

  Certain words are being replaced when used as Keywords (case-insensitive):

  'Faktura','Fakturanummer','Rechnung','Rechnungsnummer'          => 'fak'
  'Kunde','Kundenummer','Kundennummer'                            => 'kdn'
  'Ordre','Ordenummer','Bestellung','Bestellungsnummer'           => 'ord'
  'Kvittering','Kvitteringsnummer', 'Quittung','Quittungsnummer'  => 'kvi'

  
  # Options
  #
  -o,--outputdir    Specify any other directory as output directory. Default: pwd

  LONGDESC
  method_option :dryrun, :type => :boolean, :aliases => '-n', :desc => 'Run without making changes', :default => false, :required => false
  method_option ':all-keywords', :type => :boolean, :aliases => '-a', :desc => 'Add all keywords (no limit)', :default => false, :required => false
  method_option :keywords, :type => :numeric, :aliases => '-k', :desc => 'Number of keywords to include (Default: 3)', :default => 3, :required => false
  method_option :outputdir, :aliases => '-o', :type => :string, :desc => 'Speficy output directory', :default => :false, :required => :false
  def rename(filename)
    metadata = readMetadata(filename).each do |key,value|

      # Check if the metadata is complete
      if key.match(/author|subject|createdate|title/) and value.empty?
        puts 'Missing value for ' + key
        puts 'Abort'
        exit 1
      end

    end

    date    = metadata['createdate'].gsub(/\ \d{2}\:\d{2}\:\d{2}.*$/,'').gsub(/\:/,'')
    author  = metadata['author'].gsub(/\./,'_').gsub(/\-/,'').gsub(/\s/,'_')

    keywords_preface = ''
    case metadata['title']
    when /(Tilbudt|Angebot)/i
      doktype = 'til'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /Orderbekrefelse/i
      doktype = 'odb'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /faktura/i
      doktype = 'fak'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /order/i
      doktype = 'ord'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /(kontrakt|avtale|vertrag|contract)/i
      doktype = 'avt'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /kvittering/i
      doktype = 'kvi'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /manual/i
      doktype = 'man'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /(billett|ticket)/i
      doktype = 'bil'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    when /(informasjon|information)/i
      doktype = 'inf'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    else
      doktype = 'dok'
      keywords_preface = setKeywordsPreface(metadata,doktype.gsub(/\-/,''))
    end
    if not metadata['keywords'].empty? 
      keywords_preface == '' ? keywords = '' : keywords = keywords_preface
      keywordsarray    = metadata['keywords'].split(',')

      #
      # Sort array
      #
      keywordssorted = Array.new
      keywordsarray.each_with_index do |value,index|
        value = value.lstrip.chomp
        value = value.gsub(/(Faktura|Rechnungs)(nummer)? /i,'fak')
        value = value.gsub(/(Kunde)(n)?(nummer)? /i,'kdn')
        value = value.gsub(/(Kunde)(n)?(nummer)?-/i,'kdn')
        value = value.gsub(/(Ordre|Bestellung)(s?nummer)? /i,'ord')
        value = value.gsub(/(Kvittering|Quittung)(snummer)? /i,'kvi')
        value = value.gsub(/\s/,'_')
        keywordsarray[index] = value
        if value.match(/^(fak|kdn|ord|kvi)/)
          keywordssorted.insert(0, value)
        else
          keywordssorted.push(value)
        end
      end

      counter = 0
      keywordssorted.each_with_index do |value,index|

        # Exit condition limits the number of keywords used in the filename
        # unless all keywords shall be added
        if not options[':all-keywords']
          counter > options[:keywords]-1 ? break : counter = counter + 1
        end
        if value.match(/(kvi|fak|ord|kdn)/i)
          keywords == '' ? keywords = '-' + value : keywords = value + '-' + keywords
        else
          keywords == '' ? keywords = '-' + value : keywords.concat('-' + value)
        end
      end
      # Normalise the keywords as well
      #
      I18n.enforce_available_locales = false
      keywords = I18n.transliterate(keywords)

    # There are no keywords
    # Rare, but it happens
    else

      # There are no keywords.
      # we are using the title and the subject
      if keywords_preface != '' 
        keywords = keywords_preface
      end

    end
    extension   = 'pdf'
    if keywords != nil and keywords[0] != '-'
      keywords = '-' + keywords
    end
    keywords == nil ? keywords = '' : ''
    newFilename = date + '-' +
      author + '-' +
      doktype +
      keywords + '.' + 
      extension

    # Output directory checks
    if options[:outputdir]
      #if not File.exist?(options[:outputdir])
      #  puts "Error: output dir '#{options[:outputdir]}' not found. Abort"
      #  exit 1
      #end
    end

    if not options[:dryrun] and filename != newFilename.downcase
      #puts "  #{filename} => #{newFilename.downcase}"
      `mv -v '#{filename}' #{newFilename.downcase}`
    else
      puts filename + "\n   => " + newFilename.downcase
    end
  end

end

DOC.start

