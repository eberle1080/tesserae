# This is an attempt to create a universal perseus parser.
#
# Chris Forstall
# 2012-01-31

use strict;
use warnings;

use XML::LibXML;
use LWP::Simple;
use File::Path qw(make_path remove_tree);

binmode STDERR, ":utf8";

# create a working directory for output

my $tess_path = "/Users/chris/Desktop/tess";
make_path($tess_path);

# process each file specified on the command line

while ( my $rec = <DATA> ) {
	
	#
	# input is three items separated by whitespace
	#
	# path_to_TEI_file	local_file		"canonical ref. abbr."
	#
	
	my ($path_tei, $text_key, $abbr) = split(/\s+/, $rec);
	
	next unless (defined $path_tei and $text_key and $abbr);
	
	#
	# parse the TEI document
	#
	
	my $doc;
	my $parser = new XML::LibXML;
	
	# if the tei path is a url beginning with http://
	# then download the file
	
	if ($path_tei =~ /^http:\/\//) {
	
		print STDERR "attempting to download $tei_path\n";
		
		my $tei = get $path_tei || {
				
			print STDERR "download failed: $!";
			next;
		}
		
		# parse
		
		print STDERR "parsing TEI\n";
		
		$doc = $parser->parse_string($tei);
		
	}
	else {
		
		print STDERR "reading $filename\n";
		
		open (my $fh, "<", $filename)	|| {

			print STDERR "can't open $filename: $!";
			next;
		}
		
		print STDERR "parsing TEI\n":
		
		$doc = $parser->parse_fh( $fh );
	
		close ($fh);
	}

	#
	# check the header for author/title
	#
	
	my @author;
	
	for ($doc->findnodes('//titleStmt/author')) {

		push @author, $_->textContent;
	}
		 
	my @title;
	
	for ($doc->findnodes('//titleStmt/title')) {
		
		# don't bother with subtitles
		
		my $type = $_->getAttributeNode('type');
		
		next if defined( $type && $type eq 'sub');
		
		push @title, $_->textContent;
	}
		 
	for (@author) {
	
		print STDERR "\tauthor: $_\n";
	}
		 
	for (@title) {
			 
		print STDERR "\ttitle: $_\n";
	}
		 
	#	 
	# look for the <text> element(s)
	#
	
	my @text = $doc->findnodes('//text');
		
	# expunge any <text> that has <text> children
		
	for ( reverse (0..$#text)) {
	
		my @child_texts = $text[$_]->findnodes('descendant::text');
		
		if (scalar(@child_texts) > 0) {

			splice(@text, $_, 1);
		}
	}
		
	# if the number of titles doesn't match the
	# number of texts, check to see whether one
	# title is actually a comma-separated list
		
	if ($#text != $#title) {
		
		for (reverse @title) {
			
			my @title_ = split(/, */, $_);
			
			if ($#title_ == $#text) { 
				@title = @title_;
				last;
			}
		}
	}
	
	print STDERR "the number of titles "
		. ( $#text == $#title ? "matches" : "doesn't match")
		. " the number of <text> nodes\n";
	
	for my $text_i (0..$#text) {
		
		# $text_i is the current index within the array
		# $text is the current <text> node
		
		my $text = $text[$text_i];
		
		# this holds lines of output
		
		my @output;
		
		# this switch tells us whether we're dealing with numbered lines
		# choices are "verse" or "prose"
		
		my $mode;
		
		# this holds verse lines, if the file is in verse
		
		my @lines;
		
		# this switch tells us whether lines are marked with <l> or <lb/>
		# choices are "l" or "lb"
		
		my $marker;
		
		#
		# look for verse lines. 
		#
		
		# first try <l>
		
		@lines = $text->findnodes('.//l');
		
		if (checkMode(\$text, \@lines) eq 'verse') {
			
			$mode = 'verse';
			$marker = 'l';
		}
		
		# otherwise try <lb />
		
		else {
			@lines = $text->findnodes('.//lb');
			
			$mode = checkMode(\$text, \@lines);
			$marker = 'lb';
		}	
		
		
		print STDERR "text $text_i appears to be $mode\n";

		#
		# Case 1: the text is verse
		#
		
		if ($mode eq "verse") {
			
			print STDERR "lines are marked with " . ($marker eq 'l' ? "<l>" : "<lb />") . "\n";
		
			# these need to have scope beyond the line loop, since
			# we may need to rely on the last line's number to guess
			# the current one.
		
			# this is the line number
		
			my $ln = 0;
		
			# this is what precedes the line number in the locus
			# I'm just initializing it to something that will never occur
		
			my $prev_context = "no context";
								
			for (@lines) {

				# get a list of all enclosing divs that are numbered
					
				my @ancestor = $_->findnodes('ancestor::div[@n] | ancestor::div1[@n] | ancestor::div2[@n]');
					
				# this variable is everything before the line number in the locus.
				# we assume that if it changes then the next line number should be 1.
					
				my $context = "";
					
				# for each numbered enclosing div, add its number and a dot
					
				for (@ancestor) {
					$context .= $_->getAttributeNode('n')->to_literal . ".";
				}
					
				# if the enclosing context has changed, reset the line numbers
					
				if ($context ne $prev_context) { 
						
					$ln = 0;
						
					# add a blank line to the output
						
					push @output, { TAG => '' };
				}
					
				# see whether the current <l> is numbered
					
				my $ln_ = $_->getAttributeNode('n');
					
				# if so, use that number for the current line
					
				if (defined $ln_) {
						
					$ln = $ln_->to_literal;
				}
					
				# otherwise, increment the working line number
					
				else {

					# after removing any non-digit characters 
					# (i.e. "23a" should be followed by 24)

					$ln =~ s/[^0-9]//g;
						
					$ln++;
				}

				#
				# Case 1a: lines are marked with <l>
				#
				
				if ($marker eq 'l') {
						
					# get the text of the line
					
					my $line = $_->textContent;
					
					# remove leading and trailing whitespace
					
					$line =~ s/\s+$//;
					$line =~ s/^\s+//;
					
					# add the line to output
					
					push @output, { TAG => "<%ABBR " . $context . $ln . ">", CONTENT => $line };
				}
		
				#
				# Case 1b: lines marked with <lb/>
				#
			
				else {
					
					# this stores the text between this <lb/> and the next one
					
					my $text;
					
					# this is the working node;
					# we're going to start with this <lb/> and move right
					# until we reach another one
					
					my $node_ = $_;
					
					# here's the loop where we inch right
					
					for (1) {
						
						# select the next sibling right
						
						$node_ = $node_->nextSibling();
						
						# if it's <lb/> we're done
						
						last if (( ! defined $node_) or ($node_->nodeName eq 'lb'));
						
						# if it's a text node, add it
						# to the working text.
						
						if ($node_->nodeType == 3) {
							
							$text .= $node_->textContent;
						}
					}
					
					# make sure $text isn't undefined, even if the line is blank
					
					$text = $text || "";
					
					# remove any newlines, leading/trailing whitespace
					
					$text =~ s/\n/ /g;
					$text =~ s/\s+/ /g;
					$text =~ s/^ //;
					$text =~ s/ $//g;
					
					push @output, { TAG => "<$abbr " . $context . $ln . ">",
									CONTENT => $text };
				}
				
				$prev_context = $context;
			}
				
			#
			# write the output file
			#
						
			# if there are multiple texts, append a counter
			
			my $file_out = $tess_path . $text_key;
			
			if ($#text > 0) { $file_out .= $text_i }
			
			$file_out .= ".tess";
					
			print STDERR "writing $file_out";
			
			# if we can figure out the internal title of this text,
			# it might help the user rename the file
			
			if ($#title == $#text) { print STDERR " ($title[$text_i])" }
			
			print STDERR "\n";
				
			# write the file
				
			open (FH, ">", "$file_out") || {
				
				print STDERR "can't write to $file_out: $!";
				next;
			}
			
			binmode FH, ":utf8";
			
			for (@output) {

				if ($$_{TAG} ne "") {

					print FH "$$_{TAG}\t$$_{CONTENT}\n";
				}
				else {
					
					print FH "\n";
				}
			}
				
			close FH;
		}
		
		#
		# Case 2: the text is prose
		#
		
		else {
			
		}
	}
}


#
# subroutines
#

# this guesses whether the current text is verse or prose
# based on the number of bytes per line

sub checkMode {
	
	my $text_ref = shift;
	my $lines_ref = shift || [];
	
	my $text = $$text_ref;
	my @lines = @$lines_ref;
		
	if ($#lines < 0) { return 'prose' }
		
	my $test = int(length($text->textContent) / scalar(@lines));
	
	my $mode = ($test < 100 ? "verse" : "prose");
	
	return $mode;
}