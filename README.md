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

Literals are static declarations of characters or regular expressions designed for reuse in the grammar. These can be constants or variables.

    ALPHA = /[A-Za-z]/
    DIGIT = /[0-9]/
    period = "."

Literals can also accept multiple definitions

    vowel = "a" | "e" | "i" | "o" | "u"
    alpha = /[A-Z]/ | /[a-z]/

### Defining Rules for Values

Before you can start parsing a string you will need to define rules that you will use to accept or reject that string. There are many different types of rules available in kpeg 

The most basic of these rules is a string capture
  
    alpha = < /[A-Za-z]/ > { text }

While this looks very much like the ALPHA literal defined above it differs in one important way, the text captured by the rule defined between the < and > symbols will be set as the text variable in block that follows. You can also explicitly define the variable that you would like but only with existing rules or literals.
    
    num = /[1-9][0-9]*/
    sum = < num:n1 "+" num:n2 > { n1 + n2 }
    
Additionally blocks can return true or false values based upon an expression within the block. To test if something is true do the following:

    greater_than_10 = < num:n > &{ n > 10 }
    
To test for a false value do the following:

    not_greater_than_10 = < num:n > !{ n > 10 }
    
Rules can also act like functions and take parameters, an example of this is can be lifted from the [Email List Validator](https://github.com/andrewvc/email_address_validator), where an ascii value is passed in and the character is evaluated against it returning a true if it matches
    
    d(num) = <.> &{ text[0] == num }
    


## Projects using kpeg

[Dang](https://github.com/veganstraightedge/dang)
[Email Address Validator](https://github.com/andrewvc/email_address_validator)
[Callisto](https://github.com/dwaite/Callisto)
[Doodle](https://github.com/vito/doodle)