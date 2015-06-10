# Scripts
This is the scripts branch.


## Bash

* `ssh/ssh_brute_force_blocker.rhel3.6.sh`  
  Blocking incoming SSH connections after multiple failed attempts. Used to fight of Brute-Force attacks.
  Runs under RedHat 3.6.

## Ruby
* `jekyll/gitlog`
  Plugin for jekyll to use the tag 'gitupdates' which will be replaced with the notes of the latest comits from the posting folder. This keeps an automatically updated list in the blogg.
* `pdf/pmd.rb`  
  <strike>Showing and updating PDF metadata, renaming the file accordingly.</strike> Moved into gem _pdfmd_.
* `scan`
  Example script for scanning documents right into PDF files.
* `revealmgmt.rb`  
  Working with the presentation framework [reveal.js](http://lab.hakim.se/reveal-js/#/): Packing it up in a tgz file for sending or setting up a new one.
* `puppet/pre-commit`  
  Simple pre commit hook for checking pp files for Puppet. Ignores deleted files.

