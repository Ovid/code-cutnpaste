package Code::CutNPaste;

use 5.006;

use autodie;
use Capture::Tiny qw(capture);
use Carp;
use File::Find::Rule;
use File::HomeDir;
use File::Slurp;
use File::Spec::Functions qw(catfile catdir);
use Getopt::Long;
use Moo;
use Parallel::ForkManager;
use Term::ProgressBar;
use aliased 'Code::CutNPaste::Duplicate';
use aliased 'Code::CutNPaste::Duplicate::Item';
use utf8::all;

has 'renamed_vars'  => ( is => 'ro' );
has 'renamed_subs'  => ( is => 'ro' );
has 'verbose'       => ( is => 'ro' );
has 'window'        => ( is => 'rwp', default => sub {5} );
has 'jobs'          => ( is => 'ro', default => sub {1} );
has 'show_warnings' => ( is => 'ro' );
has 'threshold' => (
    is      => 'rwp',
    default => sub {.75},
    isa     => sub {
        no warnings 'uninitialized';
        my $threshold = 0 + shift;
        if ( $threshold < 0 or $threshold > 1 ) {
            croak("threshold must be between 0 and 1, inclusive");
        }
    },
);
has 'dirs' => (
    is      => 'ro',
    default => sub {'lib'},
    coerce  => sub {
        my $dirs = shift;
        unless ( ref $dirs ) {
            $dirs = [$dirs];
        }
        return $dirs;
    },
    isa => sub {
        my $dirs = shift;
        for my $dir (@$dirs) {
            unless ( -d $dir ) {
                croak("Cannot find directory '$dir'");
            }
        }
    },
);

has 'files' => (
    is      => 'ro',
    default => sub { [] },
    isa     => sub {
        my $files = shift;
        unless ( 'ARRAY' eq ref $files ) {
            croak("Argument to files must be an array reference of files");
        }
        for my $file (@$files) {
            unless ( -f $file && -r _ ) {
                croak("File '$file' does not exist or cannot be read");
            }
        }
    },
);

has 'ignore' => (
    is     => 'ro',
    coerce => sub {
        my $ignore = shift;
        return unless defined $ignore;
        return $ignore if ref $ignore eq 'Regexp';
        if ( !ref $ignore ) {
            $ignore = qr/$ignore/;
        }
        if ( 'ARRAY' eq ref $ignore ) {
            return unless @$ignore;
            $ignore = join '|' => @$ignore;
            $ignore = qr/$ignore/;
        }
        return $ignore;
    },
    isa => sub {
        return unless defined $_[0];
        croak("ignore must be a qr/regex/!")
          unless 'Regexp' eq ref $_[0];
    },
);

has 'cache_dir' => (
    is      => 'ro',
    default => sub {
        my $homedir = File::HomeDir->my_home;
        return catdir( $homedir, '.cutnpaste' );
    },
);

has '_duplicates' => (
    is      => 'ro',
    default => sub { [] },
);
has '_find_dups_called' => ( is => 'rw' );

# XXX I don't expect this to be normal, but I have found this when I run this
# code against its own codebase due to "subroutine redefined" warnings
has '_could_not_deparse' => ( is => 'ro', default => sub { {} } );

=head1 NAME

Code::CutNPaste - Find Duplicate Perl Code

=head1 VERSION

Version 0.03

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

    use Code::CutNPaste;

    my $cutnpaste = Code::CutNPaste->new(
        dirs         => [ 'lib', 'path/to/other/lib' ],
        renamed_vars => 1,
        renamed_subs => 1,
    );
    my $duplicates = $cutnpaste->duplicates;

    foreach my $duplicate (@$duplicates) {
        my ( $left, $right ) = ( $duplicate->left, $duplicate->right );
        printf <<'END', $left->file, $left->line, $right->file, $right->line;

    Possible duplicate code found
    Left:  %s line %d
    Right: %s line %d

    END
        print $duplicate->report;
    }

=cut

sub BUILD {
    my $self = shift;

    my $cache_dir = $self->cache_dir;
    $self->_set_window(5) unless defined $self->window;
    $self->_set_threshold(.75) unless defined $self->threshold;

    if ( -d $cache_dir ) {
        my @cached = File::Find::Rule->file->in($cache_dir);
        unlink $_ for @cached;
    }
    else {
        mkdir $cache_dir;
    }
    for my $dir ( @{ $self->dirs } ) {
        my @files =
          grep { !/^\./ }
          File::Find::Rule->file->name( '*.pm', '*.t', '*.pl' )->in($dir);

        # XXX dups and subdirs?
        push @{ $self->files } => @files;
    }
}

sub find_dups {
    my $self = shift;
    $self->_find_dups_called(1);
    my $files     = $self->files;
    my $num_files = @$files;

    my @pairs;
    for my $i ( 0 .. $#$files - 1 ) {
        my $next = $i + 1;
        for my $j ( $next .. $#$files ) {
            push @pairs => [ @{$files}[ $i, $j ] ];
        }
    }

    my $jobs = $self->jobs;

    my $fork = Parallel::ForkManager->new( $jobs || 1 );

    $fork->run_on_finish(
        sub {
            my $duplicates = pop @_;
            push @{ $self->_duplicates } => @$duplicates;
        }
    );
    my @left_right;
    if ( $jobs > 1 ) {
        my $files_per_job = int( $num_files / $jobs );
        for ( 1 .. $jobs ) {
            if ( $_ < $jobs ) {
                push @left_right => splice @pairs, 0, $files_per_job;
            }
            else {
                push @left_right => @pairs;
            }
        }
    }
    else {
        @left_right = @pairs;
    }

    my $progress;
    $progress = Term::ProgressBar->new(
        {   count => scalar @left_right,
            ETA   => 'linear',
        }
    ) if $self->verbose;
    my $count = 1;
    foreach my $next_files (@left_right) {
        $progress->update( $count++ ) if $self->verbose;
        my $pid = $fork->start and next;

        my $duplicates_found = $self->search_for_dups(@$next_files);

        $fork->finish( 0, $duplicates_found );
    }
    $fork->wait_all_children;
}

sub duplicates {
    my $self = shift;
    $self->find_dups unless $self->_find_dups_called;
    return $self->_duplicates;
}

sub search_for_dups {
    my ( $self, $first, $second ) = @_;
    my $window = $self->window;

    my $code1 = $self->get_text($first)  or return [];
    my $code2 = $self->get_text($second) or return [];

    my %in_second = map { $_->{key} => 1 } @$code2;

    my $matches_found = 0;
    my $last_found    = 0;
    foreach my $i ( 0 .. $#$code1 ) {
        if ( $in_second{ $code1->[$i]{key} } ) {
            if ( $i == $last_found + 1 ) {
                $matches_found++;
            }
            $last_found = $i;
        }
    }
    if ( $matches_found < $window ) {
        return [];
    }

    # brute force is bad!

    my @duplicates_found;
  LINE: foreach ( my $i = 0; $i < @$code1 - $window; $i++ ) {
        next LINE unless $in_second{ $code1->[$i]{key} };

        my @code1 = @{$code1}[ $i .. $#$code1 ];
        foreach my $j ( 0 .. $#$code2 - $window ) {
            my @code2   = @{$code2}[ $j .. $#$code2 ];
            my $matches = 0;
            my $longest = 0;
          WINDOW: foreach my $k ( 0 .. $#code1 ) {
                if ( $code1[$k]{key} eq $code2[$k]{key} ) {
                    $matches++;
                    my $length1 = length( $code1[$k]{code} );
                    if ( $length1 > $longest ) {
                        $longest = $length1;
                    }
                    my $length2 = length( $code2[$k]{code} );
                    if ( $length2 > $longest ) {
                        $longest = $length2;
                    }
                }
                else {
                    last WINDOW;
                }
            }

            # if too many lines don't meet our threshold level, don't report
            # this block of code
            if ( $matches >= $window ) {
                $matches = 0
                  if $self->_match_below_threshold( $matches, \@code1 );
            }
            if ( $matches >= $window ) {
                my $line1 = $code1[0]{line};
                my $line2 = $code2[0]{line};

                my ( $left, $right, $report ) = ( '', '', '' );
                for ( 0 .. $matches - 1 ) {
                    $left  .= $code1[$_]{code} . "\n";
                    $right .= $code2[$_]{code} . "\n";
                    my ( $line1, $line2 ) =
                      map { chomp; $_ } ( $code1[$_]{code}, $code2[$_]{code} );
                    $report
                      .= $line1 . ( ' ' x ( $longest - length($line1) ) );
                    $report .= " | $line2\n";
                }

                # Next duplicate report should start after this chunk of code
                $i += $matches;

                my $ignore = $self->ignore;
                if ( $ignore and $report =~ /$ignore/ ) {
                    next LINE;
                }
                push @duplicates_found => Duplicate->new(
                    left => Item->new(
                        file => $first,
                        line => $line1,
                        code => $left,
                    ),
                    right => Item->new(
                        file => $second,
                        line => $line2,
                        code => $right,
                    ),
                    report => $report,
                );
            }
        }
    }
    return \@duplicates_found;
}

sub _match_below_threshold {
    my ( $self, $matches, $code ) = @_;

    return unless $self->threshold;

    my $total = 0;
    for ( 0 .. $matches - 1 ) {
        $total++ if $code->[$_]{code} =~ /\w/;
    }
    return $self->threshold > $total / $matches;
}

sub get_text {
    my ( $self, $file ) = @_;

    my $filename = $file;
    $filename =~ s/\W/_/g;
    $filename = catfile( $self->cache_dir, $filename );

    my $filename_munged = $filename . ".munged";
    my ( @contents, @munged );
    if ( -f $filename ) {
        @contents = split /(\n)/ => read_file($filename);

        # sometimes another fork has already written the $filename, but not
        # yet written the $filename_munged, so we will wait up to three
        # seconds for it before trying to read it.
        # A better ordering of the @pairs might help?
        my $retry = 1;
        while ( !-f $filename_munged ) {
            sleep 1;
            last if $retry++ > 3;
        }
        @munged = split /(\n)/ => read_file($filename_munged);
    }
    else {
        my $stderr;
        ( undef, $stderr, @contents ) =
          capture {qx($^X -Ilib -MO=CutNPaste $file)};
        undef $stderr if $stderr =~ /syntax OK/;
        if ( $stderr and !$self->_could_not_deparse->{$file} ) {
            warn "Problem when parsing $file: $stderr"
              if $self->show_warnings;
        }
        undef $stderr;
        write_file( $filename, @contents );

        local $ENV{RENAME_VARS} = $self->renamed_vars || 0;
        local $ENV{RENAME_SUBS} = $self->renamed_subs || 0;
        ( undef, $stderr, @munged ) =
          capture {qx($^X -Ilib -MO=CutNPaste $file)};
        undef $stderr if $stderr =~ /syntax OK/;
        if ( $stderr and !$self->_could_not_deparse->{$file} ) {
            warn "\nProblem when parsing $file: $stderr"
              if $self->show_warnings;
        }
        write_file( $filename_munged, @munged );
    }
    return $self->add_line_numbers( $file, \@contents, \@munged );
}

sub add_line_numbers {
    my $self = shift;
    my $file = shift;
    return if $self->_could_not_deparse->{$file};
    my $contents = $self->prefilter(shift);
    my $munged   = $self->prefilter(shift);

    if ( @$contents != @$munged ) {
        warn <<"END";

There was a problem parsing $file. It will be skipped.
Try rerunning with show_warnings => 1.

END
        $self->_could_not_deparse->{$file} = 1;
        return;
    }
    my @contents;

    my $line_num = 1;
    foreach my $i ( 0 .. $#$contents ) {
        my ( $line, $munged_line ) = ( $contents->[$i], $munged->[$i] );
        chomp $line;
        chomp $munged_line;

        if ( $line =~ /^#line\s+([0-9]+)/ ) {
            $line_num = $1;
            next;
        }
        push @contents => {
            line => $line_num,
            key  => $self->make_key($munged_line),
            code => $line,
        };
        $line_num++;
    }
    return $self->postfilter( \@contents );
}

sub postfilter {
    my ( $self, $contents ) = @_;

    my @contents;
  INDEX: for ( my $i = 0; $i < @$contents; $i++ ) {
        if ( $contents->[$i]{code} =~ /^(\s*)BEGIN\s*{/ ) {    #    BEGIN {
            my $padding = $1;
            if ( $contents->[ $i + 1 ]{code} =~ /^$padding}/ ) {
                $i++;
                next INDEX;
            }
        }
        push @contents => $contents->[$i];
    }
    return \@contents;
}

sub prefilter {
    my ( $self, $contents ) = @_;
    my @contents;
    my %skip = (
        sub_begin => 0,
    );
    my $skip = 0;

  LINE: for ( my $i = 0; $i < @$contents; $i++ ) {
        local $_ = $contents->[$i];
        next if /^\s*(?:use|require)\b/;    # use/require
        next if /^\s*$/;                    # blank lines
        next if /^#(?!line\s+[0-9]+)/;  # comments which aren't line directives

        # Modules which import things create code like this:
        #
        #     sub BEGIN {
        #         require strict;
        #         do {
        #             'strict'->import('refs')
        #         };
        #     }
        #
        # $skip{sub_begin} filters this out

        if (/^sub BEGIN {/) {
            $skip{sub_begin} = 1;
            $skip++;
        }
        elsif ( $skip{sub_begin} and /^}/ ) {
            $skip{sub_begin} = 0;
            $skip--;
            next;
        }

        push @contents => $_ unless $skip;
    }
    return \@contents;
}

sub make_key {
    my $self = shift;
    local $_ = shift;
    chomp;
    s/\s//g;
    return $_;
}

1;
__END__

=head1 DESCRIPTION

A simple, heuristic code duplication checker. Will not work if the code does
not compile. See the L<find_duplicate_perl> program which is installed with
it.

=head1 Attributes to constructor

=head2 C<dirs>

An array ref of dirs to search for Perl code. Defaults to 'lib'.

=head2 C<files>

An array ref of files to be examined (will be added to dirs, above).

=head2 C<renamed_vars>

Will report duplicates even if variables are renamed.

=head2 C<renamed_subs>

Will report duplicates even if subroutines are renamed.

=head2 C<window>

Minumum number of lines to compare between files. Default is 5.

=head2 C<verbose>

This code can be very slow. Will print extra information to STDERR if
verbose is true. This lets you know it hasn't hung.

=head2 C<jobs>

Takes an integer. Defaults to 1. This is the number of jobs we'll try to run
to gather this data. On multi-core machines, you can easily use this to max
our your CPU and speed up duplicate code detection.

=head2 C<threshold>

A number between 0 and 1. It represents a percentage. If a duplicate section
of code is found, the percentage number of lines of code containing "word"
characters must exceed the threshold. This is done to prevent spurious
reporting of chunks of code like this:

         };          |         };
     }               |     }
     return \@data;  |     return \@attrs;
 }                   | }
 sub _confirm {      | sub _execute {

The above code has on 40% of its lines containing word (C<qr/\w/>) characters,
and thus will not be reported.

=head1 TODO

=over 4

=item * Add Levenstein edit distance

=item * Mask off strings.

It's amazing how many strings I'm finding which hide duplicates.

=back

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-code-cutnpaste at
rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Code-CutNPaste>.  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Code::CutNPaste

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Code-CutNPaste>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Code-CutNPaste>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Code-CutNPaste>

=item * Search CPAN

L<http://search.cpan.org/dist/Code-CutNPaste/>

=back

=head1 ACKNOWLEDGEMENTS

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Curtis "Ovid" Poe.

This program is free software; you can redistribute it and/or modify it under
the terms of either: the GNU General Public License as published by the Free
Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;    # End of Code::CutNPaste
