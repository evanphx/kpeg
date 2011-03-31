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

Literals are static declarations of characters or regular expressions designed for reuse in the grammar. These can be constants or variables. Literals can take strings, regular expressions or character ranges

    ALPHA = /[A-Za-z]/
    DIGIT = /[0-9]/
    period = "."
    string = "a string"
    regex = /(regexs?)+/
    char_range = [b-t]

Literals can also accept multiple definitions

    vowel = "a" | "e" | "i" | "o" | "u"
    alpha = /[A-Z]/ | /[a-z]/
    

### Defining Rules for Values

Before you can start parsing a string you will need to define rules that you will use to accept or reject that string. There are many different types of rules available in kpeg 

The most basic of these rules is a string capture
  
    alpha = < /[A-Za-z]/ > { text }
    

While this looks very much like the ALPHA literal defined above it differs in one important way, the text captured by the rule defined between the < and > symbols will be set as the text variable in block that follows. You can also explicitly define the variable that you would like but only with existing rules or literals.
    
    letter = alpha:a { a }
    
Additionally blocks can return true or false values based upon an expression within the block. To return true if a test passes do the following:

    match_greater_than_10 = < num:n > &{ n > 10 }
    
To test and return a false value if the test passes do the following:

    do_not_match_greater_than_10 = < num:n > !{ n > 10 }
    
Rules can also act like functions and take parameters, an example of this is can be lifted from the [Email List Validator](https://github.com/larb/email_address_validator), where an ascii value is passed in and the character is evaluated against it returning a true if it matches
    
    d(num) = <.> &{ text[0] == num }

Rules support some regular expression syntax like maybe, many, kleene and groupings for matching

    letters = alpha+
    words = alpha+ space* period?
    sentence = (letters+ | space+)+
  
    
### Defining Actions

Illustrated above in some of the examples, kpeg allows you to perform actions based upon a match that are described in block provided or in the rule definition itself.

    num = /[1-9][0-9]*/
    sum = < num:n1 "+" num:n2 > { n1 + n2 }

### Referencing an external grammar

Kpeg allows you to run a rule that is defined in an external grammar. This is useful if there is a defined set of rules that you would like to reuse in another parser. To do this create your grammar and generate a parser using the kpeg command line tool.

    kpeg literals.kpeg

Once you have the generated parser, include that file into your new grammar

    %{
      require "literals.kpeg.rb"
    }
    
Then create a variable to hold to foreign interface and pass it that class name of your parser, in this case my parser class name is Literal 

    %foreign_grammer = Literal

You can then use rules defined in the foreign grammar in the local grammar file like so

    sentence = (%foreign_grammer.alpha %foreign_grammer.space*)+ %foreign_grammer.period

    
### Generating and running your parser

Before you can generate your parser you will need to define a root rule. This will be the first rule run against the string provided to the parser

    root = sentence
    
To generate the parser run the kpeg command with the kpeg file(s) as an argument. This will generate a ruby file with the same name as your grammar file.

    kpeg example.kpeg
    
Include your generated parser file into an application that you want to use the parser in and run it. Create a new instance of the parser and pass in the string you want to evaluate. When parse is called on the parser instance it will return a true if the sting is matched, or false if it doesn't. 

    require "example.kpeg.rb"
    
    parser = Example::Parser.new(string_to_evaluate)
    parser.parse
    

## Examples

There are several examples available in the /examples directory

## Projects using kpeg

[Dang](https://github.com/veganstraightedge/dang)

[Email Address Validator](https://github.com/larb/email_address_validator)

[Callisto](https://github.com/dwaite/Callisto)

[Doodle](https://github.com/vito/doodle)