#!/usr/bin/env ruby
# == File: pdfmetadata.rb
#
# Show and edit Metadata of PDF files and rename the files accordingly.
#
# === Requirements
#
# ==== Ruby gems:
# - thor
# - highline/import
# - fileutils
# - i18n
# - pathname
# - logger
#
# ==== OS applications:
#
# - exiftools
#
# === Usage
#
#   $ ./pdfmetadata <action> <parameter> file
#
#   $ ./pdfmetadata help <action>
#
# An overview about the actions can be seen when running the script without
# any parameters
#
# === Changelog
#
# Version 1.1
# - Added Function to sort pdf documents into a directory structure based on
#   the author of the document.
# - Added dependency 'pathname'
# - Added dependency 'logger'
# - Added dependency 'i18n'
# - Added method 'sort'
# - Changing a tag will now output the old value in the edit dialog.
# - Updated documentation and descriptions of methods
#
# Version 1.0
# - Added documentation in long description of the commands
# - Added method "explain" for further information
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
# * Subject
# * Keywords (optional)
#
# TODO: Include password protected PDF documents as well
# TODO: Fix broken PDF files automatically
# TODO: Enable logging in more functions than only "sort"
# gs \
#   -o repaired.pdf \
#   -sDEVICE=pdfwrite \
#   -dPDFSETTINGS=/prepress \
#   corrupted.pdf
#
# == Author
#
# Daniel Roos <daniel-git@micronarrativ.org>
# Source: https://github.com/Micronarrativ/micronarrativ/tree/scripts
#
require "thor"
require "highline/import"
require "fileutils"
require "i18n"
require 'pathname'
require 'logger'

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
  # TODO: Enable additional options
  #
  desc 'show', 'Show metadata of a file'
  method_option :all, :type => :boolean, :aliases => '-a', :desc => 'Show all metatags', :default => false, :required => false
  method_option :tag, :type => :string, :aliases => '-t', :desc => 'Show specific tag(s), comma separated', :required => false
  long_desc <<-LONGDESC
  == General

  Show metatags of a PDF document.

  The following tags are being shown:
  \x5 * Author
  \x5 * Creator
  \x5 * CreateDate
  \x5 * Title
  \x5 * Subject
  \x5 * Keywords

  == Parameters

  --all, -a
  \x5 Show all relevant metatags for a document.

  Relevant tags are Author,Creator, CreateDate, Title, Subject, Keywords.

  --tag, -t
  \x5 Specify the metatag to show. The selected metatag must be one of the relevant tags. Other tags are ignored and nothing is returned.

  == Example

  # Show default metatags for a pdf document
  \x5>CLI show <filename>

  # Show default metatags for example.pdf
  \x5>CLI show example.pdf

  # Show value for metatag 'Author' for the file example.pdf
  \x5>CLI show -t author example.pdf

  # Show value for metatags 'Author','Title' for the file example.pdf
  \x5>CLI show -t author,title example.pdf

  LONGDESC
  def show(filename)
    metadata = readMetadata(filename)

    # Output all metatags
    if options[:all] or options[:tag].nil?
      puts "Author      : " + metadata['author'].to_s
      puts "Creator     : " + metadata['creator'].to_s
      puts "CreateDate  : " + metadata['createdate'].to_s
      puts "Subject     : " + metadata['subject'].to_s
      puts "Title       : " + metadata['title'].to_s
      puts "Keywords    : " + metadata['keywords'].to_s

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
  desc 'edit', 'Edit Meta Tag(s)'
  long_desc <<-LONGDESC
  == General

  Command will edit the metadata of a PDF document. Multiple values can be
  specified or 'all'.

  The command will invoke an interactive user input and request the values
  for the metatag.

  Additionally the file can be renamed at the end according to the new meta
    tags. See `$ #{__FILE__} help rename` for details.

  == Parameters

  --tag, -t
  \x5 Names or list of names of Metatag fields to set, separated by commata.

  --rename, -r
  \x5 Rename file after updating the meta tag information according to the fields.

  This parameter is identical to running `> CLI rename <filename>`

  General example:

  # Edit tag 'TAG' and set a new value interactive.
  \x5>CLI edit -t TAG <filename>

  # Edit tag 'Author' and set new value interactive.
  \x5>CLI edit -t author example.pdf

  # Edit mulitple Tags and set a new value.
  \x5>CLI edit -t tag1,tag2,tag3 <filename>


  == Multiple Tags

  For setting multiple tags list the tags comma separated.

  For setting all tags (Author, Title, Subject, CreateDate, Keywords) use the keyword 'all' as tagname.

  # Set tags 'Author', 'Title', 'Subject' in example.pdf interactivly.
  \x5>CLI edit -t author,title,subject example.pdf`

  # Set tags 'Author', 'Title', 'Subject', 'CreateDate', 'Keywords' in
  example.pdf interactive.
  \x5>CLI edit -t all example.pdf

  == Tag: CreateDate

  In order to enter a value for the 'CreateDate' field, some internal matching is going on in order to make it easier and faster to enter dates and times.

  The following formats are identified/matched:

  \x5 yyyymmdd
  \x5 yyyymmd
  \x5 yyyymmddHHMMSS
  \x5 yyyy-mm-dd HH:MM:SS
  \x5 yyyy:mm:dd HH:MM:SS
  \x5 yyyy.mm.dd HH:MM:SS
  \x5 yyyy-mm-d
  \x5 yyyy-mm-dd
  \x5 yyyy.mm.d
  \x5 yyyy.mm.dd
  \x5 yyyy:mm:d
  \x5 yyyy:mm:dd

  \x5 - If HH:MM:SS or HHMMSS is not provided, those values are automatically set to zero.
  \x5 - The output format of every timestamp is <yyyy:mm:dd HH:MM:SS>
  \x5 - When providing and invalid date, the incorrect date is rejected and the user asked to provide the correct date.

  == Rename file

  In addition to setting the tags the current file can be renamed according to
  the new metadata.

  # Set tag 'Author' and rename file example.pdf
  \x5> CLI edit -t author -r example.pdf

  See `> CLI help rename` for details about renaming.

  LONGDESC
  method_option :tag, :type => :string, :aliases => '-t', :desc => 'Name of the Tag(s) to Edit', :default => false, :required => true
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
      puts "Current value: '#{metadata[currentTag]}'"
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
  long_desc <<-LONGDESC
  == General

  Show value of the following metatags of a PDF document:

  - Author
  \x5- Creator
  \x5- CreateDate
  \x5- Subject
  \x5- Title
  \x5- Keywords

  == Example

  # Show the values of the metatags for example.pdf
  \x5>CLI show example.pdf

  LONGDESC
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
  long_desc <<-LONGDESC
  == General

  Explain some terms used with the script.

  == Example

  # Show the available subjects
  \x5>CLI explain

  # Show information about the subject 'author'
  \x5>CLI explain author

  LONGDESC
  def explain(term='')

    case term
    when ''
      puts 'Available subjects:'
      puts '- author'
      puts '- createdate'
      puts '- keywords'
      puts '- subject'
      puts '- title'
      puts ' '
      puts "Run `$ #{__FILE__} explain <subject>` to get more details."
    when 'author'
      puts '[Author]'
      puts '  The sender or creator of the document.'
    when 'createdate'
      puts '[CreateDate]'
      puts '  Date of the document. This is not the date when the file was created, but'
      puts '  the date found in the document or printed on the document.'
    when 'title'
      puts '[Title]'
      puts '  General type of the document, e.g. Manual, Invoice.'
    when 'subject'
      puts '[Subject]'
      puts '  What is the document about.'
      puts '  For example:'
      puts '  Manual: What is the manual about?'
      puts '  Invoice: Invoice number?'
      puts '  Contract: Contract number of Subject of the contract?'
      puts '  Order: Ordernumber of the document?'
    when 'keywords'
      puts '[Keywords]'
      puts '  Anything else that might be of interesst.'
      puts '  In Orders the elements that have been orders. Contracts might contain the'
      puts '  Names and adress of the involved parties.'
      puts '  '
      puts '  When writing Invoices with their numbers, these will be automatically be '
      puts '  picked up and can be integrated in the filename, e.g. "Invoicenumber 12334'
    end

  end

  #
  # Sort the files into directories based on the author
  #
  desc 'sort','Sort files into directories sorted by Author'
  long_desc <<-LONGDESC
  == General

  Will sort pdf documents into subdirectories according to the value of their
  tag 'author'.

  When using this action a logfile with all actions will be generated in the
  current working directory with the same name as the script and the ending
  '.log'. This can be disabled with the parameter 'log' if required.

  If a document does not have an entry in the meta tag 'author', the file will
  not be processed. This can be seen in the output of the logfile as well.

  === Parameters

  [*destination|d*]
  \x5 Speficy the root output directory to where the folderstructure is being created.

    This parameter is required.

  [*copy|c*]
  \x5 Copy the files instead of moving them.

  [*log|l*]
  \x5 Disable/Enable the logging.
  \x5 Default: enabled.

  === Replacement rules

  The subdirectories for the documents are generated from the values in the
  tag 'author' of each document.

  In order to ensure a clean directory structure, there are certain rules
  for altering the values.
  \x5 1. Whitespaces are replaced by underscores.
  \x5 2. Dots are replaced by underscores.
  \x5 3. All letters are converted to their lowercase version.
  \x5 4. Special characters are serialized

  === Example

    This command does the following:
    \x5 1. Take all pdf documents in the subdirectory ./documents.
   \x5 2. Create the output folder structure in `/tmp/test/`.
   \x5 3. Copy the files instead of moving them.
   \x5 4. Disable the logging.
   \x5> CLI sort -d /tmp/test -c -l false ./documents

  LONGDESC
  method_option :destination, :aliases => '-d', :required => true, :type => :string, :desc => 'Defines the output directory'
  method_option :copy, :aliases => '-c', :required => false, :type => :boolean, :desc => 'Copy files instead of moving them'
  method_option :log, :aliases => '-l', :require => false, :type => :boolean, :desc => 'Enable/Disable creation of log files', :default => true
  def sort(inputDir = '.')

    destination = options[:destination]
    logenable   = options[:log]
    logenable ? $logger = Logger.new(Dir.pwd + "/#{__FILE__}.log") : ''

    # Input validation
    !File.exist?(inputDir) ? abort('Input directory does not exist. Abort.'): ''
    File.directory?(inputDir) ? '' : abort('Input is a single file')
    File.file?(destination) ? abort("Output '#{destination}' is an existing file. Cannot create directory with the same name. Abort") : ''
    unless File.directory?(destination)
      FileUtils.mkdir_p(destination)
      $logger.info("Destination '#{destination}' has been created.")
    end

    # Iterate through all files
    Dir[inputDir.chomp('/') +  '/*.pdf'].sort.each do |file|

      metadata = readMetadata(file)
      if metadata['author'] and not metadata['author'].empty?
        author = metadata['author'].gsub(' ','_').gsub('.','_')
        I18n.enforce_available_locales = false # Serialize special characters
        author = I18n.transliterate(author).downcase
        folderdestination = destination.chomp('/') + '/' + author
        unless File.directory?(folderdestination)
          FileUtils.mkdir_p(folderdestination)
          logenable ? $logger.info("Folder '#{folderdestination}' has been created."): ''
        end
        filedestination = destination.chomp('/') + '/' + author + '/' + Pathname.new(file).basename.to_s

        # Final check before touching the filesystem
        if not File.exist?(filedestination)
          $logger.info("File '#{file}' => '#{filedestination}'")

          # Move/Copy the file
          if options[:copy]
            FileUtils.cp(file, filedestination)
          else
            FileUtils.mv(file,filedestination)
          end

        else
          logenable ? $logger.warn("File '#{filedestination}' already exists. Ignoring.") : ''
        end
      else
        logenable ? $logger.warn("Missing tag 'Author' for file '#{file}'. Skipping.") : (puts "Missing tag 'Author' for file '#{file}'. Skipping")
      end
    end

  end

  #
  # Rename the file according to the Metadata
  #
  # Scheme: YYYYMMDD-author-subject-keywords.extension
  desc 'rename', 'Rename the file according to Metadata'
  long_desc <<-LONGDESC
  == General

  Rename a file with the meta tags in the document.

  == Parameter

  --dry-run, -n
  \x5 Simulate the renaming process and show the result without changing the file.

  --all-keywords, -a
  \x5 Use all keywords from the meta information in the file name and ignore the limit.

  --keywwords, -k
  \x5 Set the number of keywords used in the filename to a new value.
  \x5 Default: 3

  --outputdir, -o
  \x5 Not implemented yet. Default output dir for the renamed file is the source directory.

  == Example

  # Rename the file according to the metatags
  \x5> CLI rename <filename>

  # Rename example.pdf according to the metatags
  \x5> CLI rename example.pdf

  # Simulate renaming example.pdf according to the metatags (dry-run)
  \x5> CLI rename -n example.pdf

  == Rules

  There are some rules regarding how documents are being renamed

  Rule 1: All documents have the following filenaming structure:

  <yyyymmdd>-<author>-<type>-<additionalInformation>.<extension>

  \x5 # <yyyymmdd>: Year, month and day identival to the meta information in the
  document.
  \x5 # <author>: Author of the document, identical to the meta information
  in the document. Special characters and whitespaces are replaced.
  \x5 # <type>: Document type, is being generated from the title field in the metadata of the document. Document type is a three character abbreviation following the following logic:

  \x5 til => Tilbudt|Angebot
  \x5 odb => Orderbekreftelse
  \x5 fak => Faktura
  \x5 ord => Order
  \x5 avt => Kontrakt|Avtale|Vertrag|contract
  \x5 kvi => Kvittering
  \x5 man => Manual
  \x5 bil => Billett|Ticket
  \x5 inf => Informasjon|Information
  \x5 dok => unknown

  If the dokument type can not be determined automatically, it defaults to 'dok'.

  # <additionalInformation>: Information generated from the metadata fields
  'title', 'subject' and 'keywords'. 

  If 'Title' or 'Keywords' contains one of the following keywords, the will be replaced with the corresponding abbreviation followed by the specified value separated by a whitespace:

  \x5 fak => Faktura|Fakturanummer|Rechnung|Rechnungsnummer
  \x5 kdn => Kunde|Kundenummer|Kunde|Kundennummer
  \x5 ord => Ordre|Ordrenummer|Bestellung|Bestellungsnummer
  \x5 kvi => Kvittering|Kvitteringsnummer|Quittung|Quittungsnummer

  Rule 2: The number of keywords used in the filename is defined by the parameter '-k'. See the section of that parameter for more details and the default value.

  Rule 3: Keywords matching 'kvi','fak','ord','kdn' are prioritised.

  Rule 4: Special characters and whitespaces are replaced: 

  \x5 ' ' => '_'
  \x5 '/' => '_'

  Rule 5: The new filename has only lowercase characters.

  == Example (detailed)

  # Example PDF with following MetaTags:
  
  \x5 Filename   : example.pdf
  \x5 Author     : John
  \x5 Subject    : new Product
  \x5 Title      : Presentation
  \x5 CreateDate : 1970:01:01 01:00:00
  \x5 Keywords   : John Doe, Jane Doe, Mister Doe

  # Renaming the file
  \x5> CLI rename example.pdf
  \x5 example.pdf => 19700101-john-dok-new_product-john_doe-jane_doe.pdf

  # Simulation to rename the file (no actual change)
  \x5> CLI rename -n example.pdf
  \x5example.pdf => 19700101-john-dok-new_product-john_doe-jane_doe.pdf

  # Renaming the file with all keywords
  \x5> CLI rename -n -a example.pdf
  \x5example.pdf => 19700101-john-dok-new_product-john_doe-jane_doe-mister_doe.pdf

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
    # This statement can probably be optimised
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
        value = value.gsub(/\//,'_')
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
      `mv -v '#{filename}' '#{newFilename.downcase}'`
    else
      puts filename + "\n   => " + newFilename.downcase
    end
  end

end

DOC.start

