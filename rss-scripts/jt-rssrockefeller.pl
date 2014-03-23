#!/usr/bin/perl
# 20120502/JT
# The script creates an RSS feed from http://www.rockefeller.no
# and drops is as rss.xml-file into the current directory.

# Based on: http://www.perl.com/pub/2001/11/15/creatingrss.html
# Based on: http://search.cpan.org/~kellan/XML-RSS-1.02/lib/RSS.pm

# 2013-05-01/JT Added routine for fetching event details
#               Added Logo for scene into description
#               Added Linking all addresses in the description
#               Fixed Headline-Bug (only showing the first row of the event)

use strict;
use LWP::Simple;    
use HTML::TokeParser;
use XML::RSS;
use DateTime;
use utf8;
use Switch;

# Calculate Date acc. RFC822
our $lastbuilddate = DateTime->now()->strftime("%a, %d %b %Y %H:%M:%S %z");
our $pubdate = DateTime->now()->strftime("%a, %d %b %Y 00:00:01 %z");

# First - LWP::Simple.  Download the page using get();.
# Oslo:
my $content = get( "http://www.rockefeller.no/" ) or die $!;

# Second - Create a TokeParser object, using our downloaded HTML.
my $stream = HTML::TokeParser->new( \$content ) or die $!;

# Finally - create the RSS object. 
my $rss = XML::RSS->new( version => "2.0\" xmlns:atom=\"http://www.w3.org/2005/Atom" );

# Prep the RSS.
$rss->channel(
	title        => "Rockefeller Program",
	link         => "http://www.rockefeller.no/",
	language     => 'nb',
        generator    => 'Perl, Perl, Perl',
        docs         => 'http://cyber.law.harvard.edu/rss/rss.html',
        managingEditor => 'rss@micronarrativ.org (Daniel R.)',
        webmaster    => 'rss@micronarrativ.org',
	pubdate	     => $pubdate,
	lastBuildDate	=> $lastbuilddate,
	description  => "Rockefeller Music Hall - John Dee Live Club & Pub - Sentrum Scene.");

# Declare variables.
my ($tag, $headline, $event_url);
my ($event_date, $event_headline, $event_description, $sceneimg, $event_location);

# First indication of a headline - A <div> tag is present.
while ( $tag = $stream->get_tag("table") ) {
    $event_location = '';
	# Inside this loop, $tag is at a <div> tag.
    # But do we have a "class="calendar_biglist_entry">" token, too?    
	if ($tag->[1]{class} && $tag->[1]{class} =~ /bkg\d*/i ) {
		
		# Set the image of the scene of the event
		$tag = $stream->get_tag('td');											# Contains the image of the location
		$tag = $stream->get_tag('img');		
		switch ( $tag->[1]{src} ) {
		    case /.+scene\_S\.gif/i {
		        $event_location = 'Sentrum Scene';
		    }
		    case /.+scene\_R\.gif/i {
		        $event_location = 'Rockefeller';   
		    }
		    case /.+scene\_J\.gif/i {
		        $event_location = 'John Dee';
		    } 
		    else {
		        $event_location = 'unkjent';
		    }
		}
		$sceneimg = '<img src="http://www.rockefeller.no'.$tag->[1]{src}.'" title="'.$event_location.'" alt="'.$event_location.'">';
		
		$tag = $stream->get_tag('td');											# Get the start date
		$event_date = $stream->get_trimmed_text('/td');		
		$tag = $stream->get_tag('td');
		$tag = $stream->get_tag('a');
		$event_url = "http://www.rockefeller.no/".$tag->[1]{href};
		
		# Try to get some text as description here... from the URL
		$event_description = &get_eventContent($event_url);
		
		# Get Headline
		$event_headline = $event_date.": ".$stream->get_text('/a');
		chomp($event_headline);
		
		
		# And that's it.  We can add our pair to the RSS channel. 
		$rss->add_item( title => $event_headline,
		   link => $event_url,
		   description => $sceneimg . $event_description,
		   guid => $event_url );
	}	
}
# And write the stuff to a rss file.
 $rss->save("rockefeller_oslo.rss");
 
# - # - # - # END OF SCRIPT, ROUTINES ARE FOLLOWING 
 
 
# Sub function to get the event description from the linked
# Page.
# This makes the script slow, because it need to get all the pages to all content first before
# it can create the RSS feed. :(
sub get_eventContent {
    my $tag = '';
    my $event_url = $_[0];
    my $event_content = get ( $event_url ) or die $!;
    my $event_stream = HTML::TokeParser->new( \$event_content ) or die $!;
    my ($event_description, $event_image, $event_headline, $event_date);
    
    # Now straight to the important stuff in the HTML source
    # Bildeleft is the empty tag in front of all the text.
    # We need this as a jump-in point.
    while ($tag = $event_stream->get_tag('span') ){
        if ($tag->[1]{class} && $tag->[1]{class} =~ /bildeleft/i ) {
            
            # If there's a picture, get it!
            # This isn't working yet. Images are ignored :(
            if ( $event_stream->get_trimmed_text ) {
                #$event_image = $event_stream->get_text() . '</br>';
            }
            $tag = $event_stream->get_tag('span');
            $tag = $event_stream->get_tag('b');
            $event_date = $event_stream->get_trimmed_text() . '</br>';
            chomp($event_date);
            
            $tag = $event_stream->get_tag('span');
            $event_headline = $event_stream->get_text();
            
            $tag = $event_stream->get_tag('span');
            $event_description = $event_image . $event_date . $event_headline . $event_stream->get_text("/span"); 
            $event_description =~ s|\s(www\.[^\s]+)| \<a href\=\"$1\" target\=\"\_new\"\>$1\<\/a>|ig;           # Linking
        }
    }
    return $event_description;
}


#
# Layout of rockefeller.no programm overview page
#
#<table width="386" border="0" cellpadding="5" cellspacing="0" class="bkg1">
#	<tr>
#		<td width="21" height="35" align="center" valign="middle">
#			<img src="/images/scene_J.gif" width="17" height="17" alt="">
#		</td>
#		<td width="52" align="left" valign="middle" class="arrdato">
#			Onsdag<br>02.05.12
#		</td>
#		<td width="180" align="left" valign="top" class="arrtittel">
#			<a href="jd020512.html">LILLASYSTER (S)<br>Supp.: Flasham</a>
#		</td>
#		<td align="right" valign="middle">
#			<a href="http://www.ticketmaster.no/cgi/request.cgi?l=NO&EVNT=OJD0205&STAGE=1&C=" class="billett" target="_new">
#				<img src="/images/status_3.gif"  width=90 height=17 align=absmiddle style="align:right" border=0 alt="">
#			</a>
#		</td>
#	</tr>
#</table>
#<table width="386" border="0" cellpadding="5" cellspacing="0" class="bkg0">
#	<tr>
#		<td width="21" height="35" align="center" valign="middle">
#			<img src="/images/scene_R.gif" width="17" height="17" alt="">
#		</td>
#		<td width="52" align="left" valign="middle" class="arrdato">
#			Torsdag<br>03.05.12
#		</td>
#		<td width="180" align="left" valign="top" class="arrtittel">
#			<a href="rf030512.html">ESTELLE </a>
#		</td>
#		<td align="right" valign="middle">
#			<a href="http://www.ticketmaster.no/cgi/request.cgi?l=NO&EVNT=ORF0305&STAGE=1&C=" class="billett" target="_new">
#				<img src="/images/status_3.gif"  width=90 height=17 align=absmiddle style="align:right" border=0 alt="">
#			</a>
#		</td>
#	</tr>
#</table>
#<table width="386" border="0" cellpadding="5" cellspacing="0" class="bkg1">
#	<tr>
#		<td width="21" height="35" align="center" valign="middle">
#			<img src="/images/scene_J.gif" width="17" height="17" alt="">
#		</td>
#		<td width="52" align="left" valign="middle" class="arrdato">
#			Torsdag<br>03.05.12
#		</td>
#		<td width="180" align="left" valign="top" class="arrtittel">
#			<a href="jd030512.html">THE LEMONHEADS (US)<br>- playing “It's a shame about Ray”<br>Supp.: Simen Tangen</a>
#		</td>
#		<td align="right" valign="middle">
#			<a href="http://www.ticketmaster.no/cgi/request.cgi?l=NO&EVNT=OJD0305&STAGE=1&C=" class="billett" target="_new">
#				<img src="/images/status_3.gif"  width=90 height=17 align=absmiddle style="align:right" border=0 alt="">
#			</a>
#		</td>
#	</tr>
#</table>


# Layout of event page
#<span class="bildeleft"></span><br clear=all><span class="bread"><b>L&oslash;rdag 
#                    04/05-2013 Rockefeller</b></span><br>
#                    <span class="head">I Leiligheten: 
#<br>Discotaket: 
#<br>DIRTYHANS 
#<br>FREDFADES 
#<br>ERIK FRA BERGEN 
#<br>DISCO SNUTEN 
#<br>RUDE LEAD</span><br>
#<span class="bread">
#Fredfades, Dirtyhans og Erik fra Bergen er kjent for mange etter å ha DJ'et boogie rundt hele byen med resten av Boogienetter crewet. Med seg har de sine to kamerater Rude Lead & Discosnuten som også er superdedikerte platesamlere. Forrige gang de spilte i Leiligheten ble det smekk fullt og god stemning med masse visuals og flotte mennesker. Den gangen het det Discoboogienight som et utfall av mangel på navn. Nå er de tilbake i full effekt under navnet Discotaket. Forvent kun det beste innen rare disco, lofi modern soul og bassheavy boogie. Lørdag 4. mai braker det altså løs igjen - kom tidlig! 
#<br><b>Dørene åpner kl. 22.00. 
#<br>Bill. kr. 50,-. Kun dørsalg og kontant betaling. 
#<br>20 år leg.</b>
#<br>
#<br>
#</span> 
