use 5.014;
use strict;
use warnings;

use HTML::HTML5::Parser ();
use Pod::Simple ();
use XML::LibXML::QuerySelector ();

{
	package TOBYINK::Pod::HTML::Helper;
	
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '0.001';
	
	use parent "Pod::Simple::HTML";
	
	sub new
	{
		my $class = shift;
		my $self  = $class->SUPER::new(@_);
		$self->perldoc_url_prefix("https://metacpan.org/module/");
		return $self;
	}
}

{
	package TOBYINK::Pod::HTML;
	
	our $AUTHORITY = 'cpan:TOBYINK';
	our $VERSION   = '0.001';
	
	use Moo;
	use Carp;
	
	has pretty => (
		is      => 'ro',
		default => sub { 0 },
	);
	
	has code_highlighting => (
		is      => 'ro',
		default => sub { 0 },
	);
	
	has code_styles => (
		is      => 'ro',
		default => sub {
			return +{
				pod           => 'color:#060',
				comment       => 'color:#060;font-style:italic',
				operator      => 'color:#000;font-weight:bold',
				single        => 'color:#909',
				double        => 'color:#909',
				literal       => 'color:#909',
				interpolate   => 'color:#909',
				words         => 'color:#333;background-color:#ffc',
				regex         => 'color:#333;background-color:#9f9',
				match         => 'color:#333;background-color:#9f9',
				substitute    => 'color:#333;background-color:#f90',
				transliterate => 'color:#333;background-color:#f90',
				number        => 'color:#39C',
				magic         => 'color:#900;font-weight:bold',
				cast          => 'color:#f00;font-weight:bold',
				pragma        => 'color:#009',
				keyword       => 'color:#009;font-weight:bold',
				core          => 'color:#009;font-weight:bold',
				line_number   => 'color:#666',
			}
		},
	);
	
	# tri-state (0, 1, undef)
	has code_line_numbers => (
		is      => 'ro',
		default => sub { +undef },
	);
	
	sub BUILD
	{
		my $self = shift;
		croak "code_line_numbers without code_highlighting will not work"
			if $self->code_line_numbers && !$self->code_highlighting;
	}
	
	sub file_to_dom
	{
		my $self = shift;
		$self->_pod_to_dom(parse_file => @_);
	}
	
	sub string_to_dom
	{
		my $self = shift;
		$self->_pod_to_dom(parse_string_document => @_);
	}
	
	sub file_to_html
	{
		my $self = shift;
		$self->_dom_to_html($self->file_to_dom(@_));
	}
	
	sub string_to_html
	{
		my $self = shift;
		$self->_dom_to_html($self->string_to_dom(@_));
	}
	
	sub file_to_xhtml
	{
		my $self = shift;
		$self->file_to_dom(@_)->toString;
	}
	
	sub string_to_xhtml
	{
		my $self = shift;
		$self->string_to_dom(@_)->toString;
	}
	
	sub _pod_to_dom
	{
		my $self = shift;
		my $dom  = $self->_make_dom( $self->_make_markup(@_) );
		$self->_dom_cleanups($dom);
		$self->_syntax_highlighting($dom) if $self->code_highlighting;
		if ($self->pretty)
		{
			require XML::LibXML::PrettyPrint;
			"XML::LibXML::PrettyPrint"->new_for_html->pretty_print($dom);
		}
		return $dom;
	}
	
	sub _make_markup
	{
		my $self = shift;
		my ($method, $input) = @_;
		
		my $tmp;
		my $p = "TOBYINK::Pod::HTML::Helper"->new;
		$p->output_string(\$tmp);
		$p->$method($input);
		return $tmp;
	}
	
	sub _make_dom
	{
		my $self = shift;
		my ($markup) = @_;
		my $dom = "HTML::HTML5::Parser"->load_html(string => $markup);
	}
	
	sub _dom_cleanups
	{
		my $self = shift;
		my ($dom) = @_;
		
		# My pod is always utf-8 or a subset thereof
		%{ $dom->querySelector('head meta') } = (charset => 'utf-8');
		
		# No useful comments
		$_->parentNode->removeChild($_) for $dom->findnodes('//comment()');
		
		# Drop these <a name> elements
		$dom->querySelectorAll('a[name]')->foreach(sub
		{
			$_->setNodeName('span');
			%$_ = (id => $_->{name});
		});
	}
	
	sub _syntax_highlighting
	{
		require PPI::Document;
		require PPI::HTML;
		
		my $self = shift;
		my ($dom) = @_;
		
		my $CSS = $self->code_styles;
		
		$dom->querySelectorAll('pre')->foreach(sub
		{
			my $pre = $_;
			my $txt = $pre->textContent;
			my $hlt = "PPI::HTML"->new(
				line_numbers => ($self->code_line_numbers // scalar($txt =~ m{^\s+#!/}s)),
			);
			my $out = $hlt->html( "PPI::Document"->new(\$txt) );
			
			$out =~ s/<br>//g;  # already in <pre>!
			
			$pre->removeChild($_) for $pre->childNodes;
			$pre->appendWellBalancedChunk($out);
			
			$pre->findnodes('.//*[@class]')->foreach(sub
			{
				$_->{style} = $CSS->{$_->{class}} if $CSS->{$_->{class}};
			});
		});
	}
	
	sub _dom_to_html
	{
		require HTML::HTML5::Writer;
		
		my $self = shift;
		return "HTML::HTML5::Writer"->new(polyglot => 1)->document(@_);
	}
}

__FILE__
__END__

=head1 NAME

TOBYINK::Pod::HTML - convert Pod to HTML like TOBYINK

=head1 SYNOPSIS

   #!/usr/bin/perl
   
   use strict;
   use warnings;
   use TOBYINK::Pod::HTML;
   
   my $pod2html = "TOBYINK::Pod::HTML"->new(
      pretty             => 1,       # nicely indented HTML
      code_highlighting  => 1,       # use PPI::HTML
      code_line_numbers  => undef,
      code_styles        => {        # some CSS
         comment   => 'color:green',
         keyword   => 'font-weight:bold',
      }
   );
   
   print $pod2html->file_to_html(__FILE__);

=head1 DESCRIPTION

Yet another pod2html converter.

Note that this module requires Perl 5.14, and I have no interest in
supporting legacy versions of Perl.

=head2 Constructor

=over

=item C<< new(%attrs) >>

Moose-style constructor.

=back

=head2 Attributes

=over

=item C<< pretty >>

If true, will output pretty-printed (nicely indented) HTML. This doesn't make
any difference to the appearance of the HTML in a browser.

This feature requires L<XML::LibXML::PrettyPrint>.

Defaults to false.

=item C<< code_highlighting >>

If true, source code samples within pod will be syntax highlighted as Perl 5.

This feature requires L<PPI::HTML> and L<PPI::Document>.

Defaults to false.

=item C<< code_line_numbers >>

If undef, source code samples within pod will have line numbers, but only if
they begin with C<< "#!" >>.

If true, all source code samples within pod will have line numbers.

This feature only works in conjunction with C<< code_highlighting >>.

Defaults to undef.

=item C<< code_styles >>

A hashref of CSS styles to assign to highlighted code. The defaults are:

   +{
      pod           => 'color:#060',
      comment       => 'color:#060;font-style:italic',
      operator      => 'color:#000;font-weight:bold',
      single        => 'color:#909',
      double        => 'color:#909',
      literal       => 'color:#909',
      interpolate   => 'color:#909',
      words         => 'color:#333;background-color:#ffc',
      regex         => 'color:#333;background-color:#9f9',
      match         => 'color:#333;background-color:#9f9',
      substitute    => 'color:#333;background-color:#f90',
      transliterate => 'color:#333;background-color:#f90',
      number        => 'color:#39C',
      magic         => 'color:#900;font-weight:bold',
      cast          => 'color:#f00;font-weight:bold',
      pragma        => 'color:#009',
      keyword       => 'color:#009;font-weight:bold',
      core          => 'color:#009;font-weight:bold',
      line_number   => 'color:#666',
   }

Which looks kind of like the Perl highlighting from SciTE.

=back

=head2 Methods

=over

=item C<< file_to_dom($filename) >>

Convert pod from file to a L<XML::LibXML::Document> object.

=item C<< string_to_dom($document) >>

Convert pod from string to a L<XML::LibXML::Document> object.

=item C<< file_to_xhtml($filename) >>

Convert pod from file to an XHTML string.

=item C<< string_to_xhtml($document) >>

Convert pod from string to an XHTML string.

=item C<< file_to_html($filename) >>

Convert pod from file to an HTML5 string.

This feature requires L<HTML::HTML5::Writer>.

=item C<< string_to_html($document) >>

Convert pod from string to an HTML5 string.

This feature requires L<HTML::HTML5::Writer>.

=back

=begin trustme

=item C<< BUILD >>

=end trustme

=head1 SEE ALSO

L<Pod::Simple>, L<PPI::HTML>, etc.

=head1 AUTHOR

Toby Inkster E<lt>tobyink@cpan.orgE<gt>.

=head1 COPYRIGHT AND LICENCE

This software is copyright (c) 2013 by Toby Inkster.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=head1 DISCLAIMER OF WARRANTIES

THIS PACKAGE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED WARRANTIES OF
MERCHANTIBILITY AND FITNESS FOR A PARTICULAR PURPOSE.
