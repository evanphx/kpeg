# Upper Parser

A parser that matches a string with alpha characters, spaces and a period and returns the string in upper case.

## Grammar

Name of the class that will be used to do the parsing
  
    %% name = Upper

A variable that I want to store the converted text for accessing later
    
    %% {
        attr_accessor :output
    }

My literals
    
    period = "."
    space = " "

A rule that states that all characters that match the regex [A-Za-z] should be returned uppercase

    alpha = < /[A-Za-z]/ > { text.upcase }

My rules that defines a word, it consists of three different cases, first that a word is an alpha followed by another word. If this matches return the alpha and the word that follows.


    word = alpha:a word:w { "#{a}#{w}" }

This rule states that a word can be an alpha followed by a space. If this matches return an alpha followed by a space

    | alpha:a space+ { "#{a} "}
      
This rule states that a word can consist of just an alpha. If this matches just return the alpha
      
    | alpha:a { a }

My rules that defines a sentence. The first states that a sentence consists of a word followed by a sentence. If this matches return the word followed by the sentence.

    sentence = < word:w sentence:s > { "#{w}#{s}" }

This rule states that a sentence can just be a word. If this matches just return the word.
    
    | word:w { w }

My rules that define a document. The first rule states that a document can be a sentence followed by a period that may have space followed by another document. If this matches return the sentence followed by a period with a space followed by the document.

    document = sentence:s period space* document:d  { "#{s}. #{d}" }

This rule states that a document can be a sentence followed by a period. If this matches return the sentence followed by a period.
          
    | sentence:s period { "#{s}." }
          
This rule states that a document can just be a sentence. If this matches just return the sentence.
          
    | sentence:s { s }

The root node it the first rule evaluated, is it essentially the starting point for your grammar. If the string provided can successfully be matched by the grammar provided store the returned document in the @output variable.

    root = document:d { @output = d }
    
## Generate the parser

To generate the parser make sure you have kpeg installed and run the following command (you may have to remove upper.kpeg.rb if it was previously generated)

    kpeg upper.kpeg
    
## Run the parser

To run the parser run the following

    ruby upper.rb

## Accepted Strings

+ a lower case string. Another lower case string.
+ A LOWER CASE STRING. ANOTHER LOWER CASE STRING.
+ a  string     with   lots  of    spaces.

## Not accepted strings (there are tons)

Anything that doesn't stick to spaces and periods, very brittle but it is a simple example