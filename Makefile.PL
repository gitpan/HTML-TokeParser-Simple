use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'         => 'HTML::TokeParser::Simple',
    'VERSION_FROM' => 'Simple.pm',
    'PREREQ_PM'    => { 
        'HTML::Parser'     => 3.25,
        'HTML::TokeParser' => 2.24,
        'Test::More'       => ''
    },
    ($] >= 5.005 ? (AUTHOR => 'Curtis "Ovid" Poe <poec@yahoo.com>') : ()),
);
