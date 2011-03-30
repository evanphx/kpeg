KPeg
====

KPeg is a simple PEG library for Ruby. It provides an API as well as native grammar to build the grammar.

KPeg strives to provide a simple, powerful API without being too exotic.

KPeg supports direct left recursion of rules via the [OMeta memoization](http://www.vpri.org/pdf/tr2008003_experimenting.pdf) trick.

## Writing your first grammar

### Setting up your grammar

All grammars start with with the class/module name that will be your parser

    %% name = Example::Parser

After that a block of ruby code can be defined that will be added into the class body of your parser. Attributes that are defines in this block can be accessed within your parser as instance variables

    %% {
      attr_accessor :something_cool
    }

### Defining literals

Literals are static declarations of characters or regular expressions designed for reuse in the grammar

    ALPHA = /[A-Za-z]/
    DIGIT = /[0-9]/
    PERIOD = "."


## Defining Rules

Rules