# NAME

Code::CutNPaste - Find Duplicate Perl Code

# VERSION

Version 0.01

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

A simple, heuristic code duplication checker. Will not work if the code does
not compile.

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

This code can be very slow. Will print extra information to STDERR if
verbose is true. This lets you know it hasn't hung.

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

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

