# NAME

Code::CutNPaste - Find Duplicate Perl Code

# VERSION

Version 0.30

# SYNOPSIS

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

# DESCRIPTION

`ALPHA` code, though it works fairly well. You probably want use the
[find_duplicate_perl](http://search.cpan.org/perldoc?find_duplicate_perl) command line program that ships with this distribution.

A simple, heuristic code duplication checker. Will not work if the code does
not compile. See the [find_duplicate_perl](http://search.cpan.org/perldoc?find_duplicate_perl) program which is installed with
it.

# Attributes to constructor

## `dirs`

An array ref of dirs to search for Perl code. Defaults to 'lib'.

## `files`

An array ref of files to be examined (will be added to dirs, above).

## `renamed_vars`

Will report duplicates even if variables are renamed.

## `renamed_subs`

Will report duplicates even if subroutines are renamed.

## `window`

Minumum number of lines to compare between files. Default is 5.

## `verbose`

This code can be very slow. If verbose is true,  will print a progress bar to
STDERR. The progress bar has an ETA, but this number seems to be fairly
unreliable. Maybe I'll remove it.

## `jobs`

Takes an integer. Defaults to 1. This is the number of jobs we'll try to run
to gather this data. On multi-core machines, you can easily use this to max
our your CPU and speed up duplicate code detection.

## `threshold`

A number between 0 and 1. It represents a percentage. If a duplicate section
of code is found, the percentage number of lines of code containing "word"
characters must exceed the threshold. This is done to prevent spurious
reporting of chunks of code like this:

            };          |         };
        }               |     }
        return \@data;  |     return \@attrs;
    }                   | }
    sub _confirm {      | sub _execute {

The above code has only 40% of its lines containing word (`qr/\w/`)
characters, and thus will not be reported.

## `noutf8`

Boolean. Default false.

Due to a bug in Perl, the following code crashes Perl in Windows:

    perl -e "use open qw{:encoding(UTF-8) :std}; fork; "
    perl -e "open $f, '>:encoding(UTF-8)', 'temp.txt'; fork"
    perl -e "use utf8::all; fork"

By setting `noutf8` to a true value, we avoid loading [utf8::all](http://search.cpan.org/perldoc?utf8::all). This may
cause undesirable results.

See also:

- [http://www.nntp.perl.org/group/perl.perl5.porters/2012/12/msg196821.html](http://www.nntp.perl.org/group/perl.perl5.porters/2012/12/msg196821.html)
- [http://perlmonks.org/?node_id=1009989](http://perlmonks.org/?node_id=1009989)

## `cache_dir`

By default, we cache "deparsed" versions of the code in
`<$ENV{HOME}/.cutnpaste`>. You can use this attribute to specify a different
cache directory.

## `show_warnings`

A boolean. If true, will display some internal warnings when trying to deparse
files. It's used for debugging, but you may find it useful. Largely gets
triggered when you try to search for duplicates in a file that you already
have in memory, or when the file in question cannot otherwise be deparsed.

## `ignore`

Takes an arrayref of regular expressions. Blocks of code matching _any_ of
the regular expressions will not be reported as duplicates.

# TODO

- Add Levenstein edit distance
- Mask off strings

It's amazing how many strings I'm finding which hide duplicates.

- Check files against themselves

Currently, we only check for duplicates in other files. Whoops!

- We need a way to skip modules

This is very important for code bases with auto-generated modules. They don't
care as much about duplicated code.

- A config file?

# AUTHOR

Curtis "Ovid" Poe, `<ovid at cpan.org>`

# BUGS

Please report any bugs or feature requests to `bug-code-cutnpaste at
rt.cpan.org`, or through the web interface at
[http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Code-CutNPaste](http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Code-CutNPaste).  I will be
notified, and then you'll automatically be notified of progress on your bug as
I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Code::CutNPaste

You can also look for information at:

- RT: CPAN's request tracker (report bugs here)

[http://rt.cpan.org/NoAuth/Bugs.html?Dist=Code-CutNPaste](http://rt.cpan.org/NoAuth/Bugs.html?Dist=Code-CutNPaste)

- AnnoCPAN: Annotated CPAN documentation

[http://annocpan.org/dist/Code-CutNPaste](http://annocpan.org/dist/Code-CutNPaste)

- CPAN Ratings

[http://cpanratings.perl.org/d/Code-CutNPaste](http://cpanratings.perl.org/d/Code-CutNPaste)

- Search CPAN

[http://search.cpan.org/dist/Code-CutNPaste/](http://search.cpan.org/dist/Code-CutNPaste/)

# ACKNOWLEDGEMENTS

# LICENSE AND COPYRIGHT

Copyright 2012 Curtis "Ovid" Poe.

This program is free software; you can redistribute it and/or modify it under
the terms of either: the GNU General Public License as published by the Free
Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.