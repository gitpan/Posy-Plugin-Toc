package Posy::Plugin::Toc;
use strict;

=head1 NAME

Posy::Plugin::Toc - Posy plugin create a table of contents.

=head1 VERSION

This describes version B<0.5101> of Posy::Plugin::Toc.

=cut

our $VERSION = '0.5101';

=head1 SYNOPSIS

    @plugins = qw(Posy::Core Posy::Plugin::Toc));
    @entry_actions = qw(header
	    ...
	    parse_entry
	    make_toc
	    render_entry
	    ...
	);

=head1 DESCRIPTION

Creates a table of contents generated from headings.

The table of contents will be generated only if the entry
contains the 'toc_split' or the 'toc_split_after' values,
and only from headers below the match.

If there are no headers (element $toc_chapter_element), then 
no table of contents will be generated.

This creates a 'make_toc' entry action, which should be placed after
'parse_entry' and before 'render_entry' in the entry_action list.  If you
are using the Posy::Plugin::ShortBody plugin, this should be placed after
'short_body' in the entry_action list, not before it.

=head2 Configuration

This expects configuration settings in the $self->{config} hash,
which, in the default Posy setup, can be defined in the main "config"
file in the config directory.

=over

=item B<toc_split>

String which will be replaced by the table of contents.
(default: <!-- toc -->)

=item B<toc_split_after>

If this is defined, then the table of contents will be placed
after the first match of this string.  This is useful for
putting a ToC after the first <h1> header in a file, for example.
This overrides toc_split if it is defined.
(default: nothing)

=item B<toc_chapter_element>

Which element marks the header of the "chapters"?
(default: h3)

=item B<toc_chapter_prefix>

This will prefix the chapters' headers.

=item B<toc_anchor>

Contents of the anchor of chapters prefix.

=item B<toc_prefix>

Prefix of the table of contents.
(default: <h3>Table of Contents</h3><ul class="PageTOC">)

=item B<toc_line_prefix>

Prefix of the line for each chapter will be inserted into the TOC 
(default: <li>)

=item B<toc_line_suffix>

Suffix of the line for each chapter will be inserted into the TOC 
(default: </li>)

=item B<toc_suffix>

Suffix of the table of contents.
(default: </ul>)

=back

=cut

=head1 OBJECT METHODS

Documentation for developers and those wishing to write plugins.

=head2 init

Do some initialization; make sure that default config values are set.

=cut
sub init {
    my $self = shift;
    $self->SUPER::init();

    # set defaults
    $self->{config}->{toc_split} = qr/<!--\s*toc\s*-->/
	if (!defined $self->{config}->{toc_split});
    $self->{config}->{toc_split_after} = ''
	if (!defined $self->{config}->{toc_split_after});
    $self->{config}->{toc_chapter_element} = 'h3'
	if (!defined $self->{config}->{toc_chapter_element});
    $self->{config}->{toc_chapter_prefix} = q:" ":
	if (!defined $self->{config}->{toc_chapter_prefix});
    $self->{config}->{toc_anchor} = q:"${chap}.":
	if (!defined $self->{config}->{toc_anchor});
    $self->{config}->{toc_prefix} = '<h3>Table of Contents</h3>
<ul class="PageTOC">'
	if (!defined $self->{config}->{toc_prefix});
    $self->{config}->{toc_line_prefix} = '<li>'
	if (!defined $self->{config}->{toc_line_prefix});
    $self->{config}->{toc_line_suffix} = "</li>\n"
	if (!defined $self->{config}->{toc_line_suffix});
    $self->{config}->{toc_suffix} = '</ul>'
	if (!defined $self->{config}->{toc_suffix});

    # initialize private things
    $self->{toc}->{entry_num} = 0;
} # init

=head1 Entry Action Methods

Methods implementing per-entry actions.

=head2 make_toc

$self->make_toc($flow_state, $current_entry, $entry_state)

Alters $current_entry->{body} by adding a table-of-contents
if the "toc_split" or the "toc_split_after" string is in the body.

=cut
sub make_toc {
    my $self = shift;
    my $flow_state = shift;
    my $current_entry = shift;
    my $entry_state = shift;

    my $body = $current_entry->{body};
    my $text;
    if ($self->{config}->{toc_split_after})
    {
	my $split_after = $self->{config}->{toc_split_after};
	$body =~ /$split_after/;
	$text = $';
	$body = join('', $`, $&);
    }
    else
    {
	($body, $text) = split $self->{config}->{toc_split}, $body, 2;
    }
  
    if ($text)
    {
	my $toc = "";
	my $toc_chapter_element = $self->{config}->{toc_chapter_element};
	my $toc_prefix = $self->{config}->{toc_prefix};
	my $toc_suffix = $self->{config}->{toc_suffix};
	$self->{toc}->{chap} = 0;

	$text =~ s:<($toc_chapter_element)(.*?)>(.*?)</$toc_chapter_element>:$self->_toc_do_stuff($1,$2,$3,\$toc):ego;
	if ($toc) {
	    my $entry_num = $self->{toc}->{entry_num};
	    $body .= "<a name='TOC${entry_num}'></a>"
	    . $self->{config}->{toc_prefix}
	    . $toc
	    . $self->{config}->{toc_suffix}
	    . $text;
	} else {
	    $body .= $text;
	}
	$current_entry->{body} = $body;
    }

    $self->{toc}->{entry_num}++;
    1;
} # make_toc

=head1 Private Methods

=head2 _toc_do_stuff

Return the stuff to be substituted in found header anchors,
and append to the $toc information.

=cut
sub _toc_do_stuff {
    my $self = shift;
    my $chap_el = shift;
    my $chap_att = shift;
    my $chap_label = shift;
    my $toc_ref = shift;

    my $entry_num = $self->{toc}->{entry_num};

    $self->{toc}->{chap}++;
    my $chap = $self->{toc}->{chap};
    my $chap_id;
    my $newhead;

    $chap_id = join('', 'toc_', ${entry_num}, '_', ${chap});
    $newhead = join('',
		    '<', $chap_el, $chap_att, '><a name="', $chap_id,
		    '" href="#TOC', $entry_num, '">',
		    eval($self->{config}->{toc_anchor}),
		    '</a>',
		    eval($self->{config}->{toc_chapter_prefix}),
		    $chap_label, '</', $chap_el, '>'
		   );

    $$toc_ref .= join('', $self->{config}->{toc_line_prefix},
		      '<a href="#', $chap_id, '">',
		      ${chap}, '. ', ${chap_label}, '</a>',
		      $self->{config}->{toc_line_suffix});

    return $newhead;
} # _toc_do_stuff

=head1 INSTALLATION

Installation needs will vary depending on the particular setup a person
has.

=head2 Administrator, Automatic

If you are the administrator of the system, then the dead simple method of
installing the modules is to use the CPAN or CPANPLUS system.

    cpanp -i Posy::Plugin::Toc

This will install this plugin in the usual places where modules get
installed when one is using CPAN(PLUS).

=head2 Administrator, By Hand

If you are the administrator of the system, but don't wish to use the
CPAN(PLUS) method, then this is for you.  Take the *.tar.gz file
and untar it in a suitable directory.

To install this module, run the following commands:

    perl Build.PL
    ./Build
    ./Build test
    ./Build install

Or, if you're on a platform (like DOS or Windows) that doesn't like the
"./" notation, you can do this:

   perl Build.PL
   perl Build
   perl Build test
   perl Build install

=head2 User With Shell Access

If you are a user on a system, and don't have root/administrator access,
you need to install Posy somewhere other than the default place (since you
don't have access to it).  However, if you have shell access to the system,
then you can install it in your home directory.

Say your home directory is "/home/fred", and you want to install the
modules into a subdirectory called "perl".

Download the *.tar.gz file and untar it in a suitable directory.

    perl Build.PL --install_base /home/fred/perl
    ./Build
    ./Build test
    ./Build install

This will install the files underneath /home/fred/perl.

You will then need to make sure that you alter the PERL5LIB variable to
find the modules, and the PATH variable to find the scripts (posy_one,
posy_static).

Therefore you will need to change:
your path, to include /home/fred/perl/script (where the script will be)

	PATH=/home/fred/perl/script:${PATH}

the PERL5LIB variable to add /home/fred/perl/lib

	PERL5LIB=/home/fred/perl/lib:${PERL5LIB}

=head1 REQUIRES

    Posy
    Posy::Core

    Test::More

=head1 SEE ALSO

perl(1).
Posy

=head1 BUGS

Please report any bugs or feature requests to the author.

=head1 AUTHOR

    Kathryn Andersen (RUBYKAT)
    perlkat AT katspace dot com
    http://www.katspace.com

=head1 COPYRIGHT AND LICENCE

Copyright (c) 2004-2005 by Kathryn Andersen

Based on the blosxom 'toc' plugin by Gregor Rayman (copyright 2003)
<rayman <at> grayman <dot> de>

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

=cut

1; # End of Posy::Plugin::Toc
__END__
