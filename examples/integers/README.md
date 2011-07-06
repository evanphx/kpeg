# Integer Parser

A parser that matches simple integer literals.

## Grammar

The interesting part of the grammar is the _digits_ rule
that uses one of its arguments as part of its expression.

Other rules (_hexadecimal_, _octal_, _binary_, and _decimal_), 
simply parametrize the _digits_ for their needs.

This example shows parametrized grammar rules that can
take other rules as arguments (by converting them to procs
like in ruby)

    
## Generate the parser

To generate the parser make sure you have kpeg installed and run the following command

    kpeg -fs integers.kpeg
    
## Run the parser

To run the parser run the following

    ruby integers.rb

## Accepted Strings

+ 0xCAFEBABE
+ +010
+ -300
+ 0b1_10_10

## Not accepted strings (there are tons)

Anything that doesn't stick to spaces and periods, very brittle but it is a simple example
