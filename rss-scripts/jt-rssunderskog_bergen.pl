#!/usr/bin/perl
# 20120430/JT
# 20140222/JT
# The script creates an RSS feed from http://www.underskog.no
# and drops is as rss.xml-file into the current directory.

# Based on: http://www.perl.com/pub/2001/11/15/creatingrss.html
# Based on: http://search.cpan.org/~kellan/XML-RSS-1.02/lib/RSS.pm
# Based on: http://perlmeme.org/tutorials/lwp.html
#
# History
# 2012-11-25  JT  Updated, siden underskog har bytte HTML og linken for lenge siden.
# 2014-02-20  JT  Updated with LWP::UserAgent to get it working again.

use strict;
use warnings;
use 5.10.1;
use utf8;
use LWP::UserAgent;
use HTTP::Request::Common qw(GET);
use HTML::TokeParser;
use XML::RSS;
use DateTime;
use URI::Find::Schemeless;

# Calculate Date acc. RFC822
our $lastbuilddate = DateTime->now()->strftime("%a, %d %b %Y %H:%M:%S %z");
our $pubdate       = DateTime->now()->strftime("%a, %d %b %Y 00:00:01 %z");

# First - LWP::UserAgent.
# Bergen:
my $ua = LWP::UserAgent->new;

# Define user agent type
$ua->agent('Mozilla/8.0');

my $req = GET 'https://underskog.no/kalender?utf8=%E2%9C%93&city=3';

# Make the request
my $res = $ua->request($req);

# Check the response
my $content;
if ($res->is_success) {
    $content = $res->content;
} else {
    print $res->status_line . "\n";
}

# Second - Create a TokeParser object, using our downloaded HTML.
my $stream = HTML::TokeParser->new( \$content ) or die $!;

# Finally - create the RSS object.
my $rss =
  XML::RSS->new( version => "2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom" );

# Create an object to find URLS in Text
my $urlfinder = URI::Find::Schemeless->new(
    sub {
        my ( $uri, $original_uri ) = @_;
        return $original_uri;
    }
);

# Prep the RSS.
$rss->channel(
    title          => "Underskog - I dag",
    link           => "http://underskog.no/",
    language       => 'nb',
    pubDate        => $pubdate,
    lastBuildDate  => $lastbuilddate,
    generator      => 'Perl, Perl, Perl',
    docs           => 'http://cyber.law.harvard.edu/rss/rss.html',
    managingEditor => 'rss@micronarrativ.org (Daniel R.)',
    webmaster      => 'rss@micronarrativ.org',
    description    => "Underskog, aktiviteter i dag."
);

# Declare variables.
my ( $tag, $headline, $url );
my (
    $event_time,     $event_headline, $event_description,
    $event_imageurl, $event_url
);

# First indication of a headline - A <div> tag is present.
while ( $tag = $stream->get_tag("div") ) {

    # Inside this loop, $tag is at a <div> tag.
    # But do we have a "class="calendar_biglist_entry">" token, too?
    if (    $tag->[1]{class}
        and $tag->[1]{class} eq 'post calendar_biglist_entry' )
    {

# We do! Then let's get the image for the posting (this time we're doing it right...)
# Reset the url though, if there's nothing.
        $tag = $stream->get_tag("div");
        if ( $tag->[1]{class} eq 'thumbnail' ) {
            $event_imageurl = $tag->[1]{style};
            $event_imageurl =~ m%(http://.*)\'%;
            $event_imageurl = $1;
        }
        else {
            $event_imageurl = '';
        }

# The next step is an <span></span> set, which we are interested in. The one defining the time
        $tag        = $stream->get_tag('span');
        $tag        = $stream->get_tag('span');
        $event_time = $stream->get_text() . "\n";    # Read the event-time
        chomp($event_time);

       # next we're heading for the <a> and the link to the article and the link
        $tag = $stream->get_tag('a');
        $event_headline =
          $event_time . " " . $stream->get_trimmed_text();   # Read the Headline
        $event_url = 'http://www.underskog.no' . $tag->[1]{href};

        # Now we're going for the description text... let's try that!
        $tag = $stream->get_tag('div');

        $tag               = $stream->get_tag('p');
        $event_description = $stream->get_text();
        $tag               = $stream->get_tag('p');
        $event_description .= $stream->get_text();    # Get the description

        #Create the HTML output for the image
        #say $event_imageurl;
        if ($event_imageurl) {
            $event_description =
                '<a href="'
              . $event_url
              . '"><img src="'
              . $event_imageurl
              . '" width="80"></a><p>'
              . $event_description . '</p>';
        }

        # And that's it.  We can add our pair to the RSS channel.
        $rss->add_item(
            title       => $event_headline,
            link        => $event_url,
            permaLink   => $event_url,
            description => $event_description,
            date        => '2012-05-12T12:00+00:00'
        );
    }
}

# And write the stuff to a rss file.
$rss->save("underskog_bergen.rss");

#
# New layout of Underskog - That's why the RSS failed
#
#<div id="event_142892" class="post calendar_biglist_entry">
#  <div class="thumbnail" style="background-image: url('<urlToArticleImage>')">
#  </div>
#  <h2>
#    <span class="event_time">
#      <span class="past_time|future_time"><event_time></span>
#    </span>
#    <a href="/kalender/91235_radiorakels-julekampanje/forestilling/142892" class="object_link">link for å lese videre</a>,
#    <span class="venue">
#      <a href="/sted/496_radiorakel-fm-99-3" class="object_link">Link Til stedet</a>
#    </span>
#  </h2>
#  <div class="body">
#    <p></p>
#    <p>
#      Text
#    </p>
#  </div>
#</div>
