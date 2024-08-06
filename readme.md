Convert Pmwiki pages to markdown files.

## Procedure
1. Install [Pmwikilib](https://www.pmwiki.org/wiki/Cookbook/Pmwikilib#install), which is a Python2 package that 
parse Pmwiki metadata into plain text (with the synytax).
2. Run converter.rb to convert the plain text from last step into markdown file.


## Coverage
Currently the simple script handles only partially the features included in the Pmwiki, including:

1. basic styles: bold, italics, ordered/unordered list, different level of heading.
2. plain table or table directives, note navigation bar is not supported.
3. links to external website, assets, images, other pages or anchors within the same page.

## Motivation and plan
The development of Pmwiki is [unclear](https://www.pmwiki.org/wiki/News/News), and the last update was back in 2022.
Time to move on to something more modern! The script is written in Ruby because the plan was to convert Pmwiki and host
the markdowns with Jekyll, which is written in Ruby, so everything can be managed nicely within the Ruby ecosystem.

The next step would be to integrate `Pmwikilib` and the converter script so it is easier to add features.
1. parse more metadata: creation time, author, last modified time, etc.
2. better handling of page title, file structure, etc.




