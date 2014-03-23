#!/usr/bin/perl
# 20120430/JT
# The script creates an RSS feed from http://www.underskog.no
# and drops is as rss.xml-file into the current directory.

# Based on: http://www.perl.com/pub/2001/11/15/creatingrss.html
# Based on: http://search.cpan.org/~kellan/XML-RSS-1.02/lib/RSS.pm

use strict;
use LWP::Simple;
use HTML::TokeParser;
use XML::RSS;
use DateTime;

# Calculate Date acc. RFC822
our $lastbuilddate = DateTime->now()->strftime("%a, %d %b %Y %H:%M:%S %z");
our $pubdate = DateTime->now()->strftime("%a, %d %b %Y 00:00:01 %z");

# First - LWP::Simple.  Download the page using get();.
# Oslo:
my $content = get( "http://underskog.no/kalender/liste?city=1&commit=Endre" ) or die $!;

# Second - Create a TokeParser object, using our downloaded HTML.
my $stream = HTML::TokeParser->new( \$content ) or die $!;

# Finally - create the RSS object. 
my $rss = XML::RSS->new( version => "2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom" );

# Prep the RSS.
$rss->channel(
	title        => "Underskog - I dag",
	link         => "http://underskog.no/",
	language     => 'nb',
	pubDate	     => $pubdate,
 	lastBuildDate => $lastbuilddate,
	generator    => 'Perl, Perl, Perl',
	docs	     => 'http://cyber.law.harvard.edu/rss/rss.html',
	managingEditor => 'rss@micronarrativ.org (Daniel R.)',
	webmaster    => 'rss@micronarrativ.org',
	description  => "Underskog, aktiviteter i dag.");

# Declare variables.
my ($tag, $headline, $url);
my ($event_time, $event_headline, $event_description);

# First indication of a headline - A <div> tag is present.
while ( $tag = $stream->get_tag("div") ) {
	# Inside this loop, $tag is at a <div> tag.
    # But do we have a "class="calendar_biglist_entry">" token, too? 
	if ($tag->[1]{class} and $tag->[1]{class} eq 'calendar_biglist_entry') {
		# We do! 
        # The next step is an <span></span> set, which we are interested in.  
		$tag = $stream->get_tag('span');			
		$tag = $stream->get_tag('span');
		$event_time =  $stream->get_text()."\n";								# Read the event-time
		chomp($event_time);
		$tag = $stream->get_tag('a');
		$event_headline = $event_time." ".$stream->get_trimmed_text();			# Read the Headline
		$tag = $stream->get_tag('span');
		$tag = $stream->get_tag('div');
		$tag = $stream->get_tag('div');
		$tag = $stream->get_tag('p');
		$event_description = $stream->get_text();								# Get the description
		$tag = $stream->get_tag('a');
		$url =  "http://underskog.no".$tag->[1]{href};							# Get the url
		# And that's it.  We can add our pair to the RSS channel. 
		$rss->add_item( title => $event_headline,
				link => $url,
				permaLink => $url,
				description => $event_description,
				date => '2012-05-12T12:00+00:00'
				 );
	}
}

# And write the stuff to a rss file.
$rss->save("underskog_oslo.rss");

#
# Layout of underskog.no
#
# <div id="event_133521" class="calendar_biglist_entry">
# 	<h3>
#        <span class="event_time">
#            <span class="future_time">09:00</span>
#        </span>
#        <a href="/kalender/86328_please-wait/forestilling/133521">Headline</a>        
#        <span class="venue">Place</span>
#      </h3>
#      	<div class="body">
#       	<div class="textile text">
#				<p>Article Text</p>
#				<p><a href="/kalender/86328_please-wait">Link for å lese videre</a></p>
#			</div>
#		</div>
# </div>
